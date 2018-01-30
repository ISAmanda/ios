//
//  UsersDataSource.m
//
//  Copyright (C) 2013 IRCCloud, Ltd.
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.


#import "UsersDataSource.h"
#import "ChannelsDataSource.h"
#import "BuffersDataSource.h"
#import "ServersDataSource.h"
#import "EventsDataSource.h"

@implementation User

-(NSString *)nick {
    return _nick;
}

-(void)setNick:(NSString *)nick {
    _nick = nick;
    _lowercase_nick = self.display_name.lowercaseString;
}

-(NSString *)lowercase_nick {
    if(!_lowercase_nick)
        _lowercase_nick = _nick.lowercaseString;
    return _lowercase_nick;
}

-(NSString *)display_name {
    if(_display_name.length)
        return _display_name;
    else
        return _nick;
}

-(void)setDisplay_name:(NSString *)display_name {
    _display_name = display_name;
    _lowercase_nick = self.display_name.lowercaseString;
}

-(NSComparisonResult)compare:(User *)aUser {
    return [_lowercase_nick localizedStandardCompare:aUser.lowercase_nick];
}

-(NSComparisonResult)compareByMentionTime:(User *)aUser {
    if(_lastMention == aUser.lastMention)
        return [_lowercase_nick localizedStandardCompare:aUser.lowercase_nick];
    else if(_lastMention > aUser.lastMention)
        return NSOrderedAscending;
    else
        return NSOrderedDescending;
}

-(id)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if(self) {
        decodeInt(_cid);
        decodeInt(_bid);
        decodeObject(_nick);
        decodeObject(_old_nick);
        decodeObject(_hostmask);
        decodeObject(_mode);
        decodeInt(_away);
        decodeObject(_away_msg);
        decodeDouble(_lastMention);
        decodeObject(_ircserver);
        decodeObject(_display_name);
    }
    return self;
}

-(void)encodeWithCoder:(NSCoder *)aCoder {
    encodeInt(_cid);
    encodeInt(_bid);
    encodeObject(_nick);
    encodeObject(_old_nick);
    encodeObject(_hostmask);
    encodeObject(_mode);
    encodeInt(_away);
    encodeObject(_away_msg);
    encodeDouble(_lastMention);
    encodeObject(_ircserver);
    encodeObject(_display_name);
}

-(NSString *)description {
    return [NSString stringWithFormat:@"{cid: %i, bid: %i, nick: %@, hostmask: %@}", _cid, _bid, _nick, _hostmask];
}
@end

@implementation UsersDataSource
+(UsersDataSource *)sharedInstance {
    static UsersDataSource *sharedInstance;
	
    @synchronized(self) {
        if(!sharedInstance)
            sharedInstance = [[UsersDataSource alloc] init];
		
        return sharedInstance;
    }
	return nil;
}

-(id)init {
    self = [super init];
    if(self) {
        [NSKeyedArchiver setClassName:@"IRCCloud.User" forClass:User.class];
        [NSKeyedUnarchiver setClass:User.class forClassName:@"IRCCloud.User"];

        if([[[NSUserDefaults standardUserDefaults] objectForKey:@"cacheVersion"] isEqualToString:[[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"]]) {
            NSString *cacheFile = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"users"];
            
            @try {
                _users = [[NSKeyedUnarchiver unarchiveObjectWithFile:cacheFile] mutableCopy];
            } @catch(NSException *e) {
                [[NSFileManager defaultManager] removeItemAtPath:cacheFile error:nil];
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"cacheVersion"];
                [[ServersDataSource sharedInstance] clear];
                [[BuffersDataSource sharedInstance] clear];
                [[ChannelsDataSource sharedInstance] clear];
                [[EventsDataSource sharedInstance] clear];
            }
        }
        if(!_users)
            _users = [[NSMutableDictionary alloc] init];
    }
    return self;
}

-(void)serialize {
    NSString *cacheFile = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) objectAtIndex:0] stringByAppendingPathComponent:@"users"];
    
    NSMutableDictionary *users = [[NSMutableDictionary alloc] init];
    @synchronized(_users) {
        for(NSNumber *bid in _users) {
            [users setObject:[[_users objectForKey:bid] mutableCopy] forKey:bid];
        }
    }
    
    @synchronized(self) {
        @try {
            [NSKeyedArchiver archiveRootObject:users toFile:cacheFile];
            [[NSURL fileURLWithPath:cacheFile] setResourceValue:[NSNumber numberWithBool:YES] forKey:NSURLIsExcludedFromBackupKey error:NULL];
        }
        @catch (NSException *exception) {
            [[NSFileManager defaultManager] removeItemAtPath:cacheFile error:nil];
        }
    }
}

-(void)clear {
    @synchronized(_users) {
        [_users removeAllObjects];
    }
}

-(void)addUser:(User *)user {
#ifndef EXTENSION
    @synchronized(_users) {
        NSMutableDictionary *users = [_users objectForKey:@(user.bid)];
        if(!users) {
            users = [[NSMutableDictionary alloc] init];
            [_users setObject:users forKey:@(user.bid)];
        }
        [users setObject:user forKey:user.lowercase_nick];
    }
#endif
}

-(NSArray *)usersForBuffer:(int)bid {
    @synchronized(_users) {
        return [[[_users objectForKey:@(bid)] allValues] sortedArrayUsingSelector:@selector(compare:)];
    }
}

-(User *)getUser:(NSString *)nick cid:(int)cid bid:(int)bid {
    @synchronized(_users) {
        return [[_users objectForKey:@(bid)] objectForKey:[nick lowercaseString]];
    }
}

-(User *)getUser:(NSString *)nick cid:(int)cid {
    @synchronized(_users) {
        for(NSDictionary *buffer in _users.allValues) {
            User *u = [buffer objectForKey:[nick lowercaseString]];
            if(u && u.cid == cid)
                return u;
        }
        return nil;
    }
}

-(void)removeUser:(NSString *)nick cid:(int)cid bid:(int)bid {
    @synchronized(_users) {
        [[_users objectForKey:@(bid)] removeObjectForKey:[nick lowercaseString]];
    }
}

-(void)removeUsersForBuffer:(int)bid {
    @synchronized(_users) {
        [_users removeObjectForKey:@(bid)];
    }
}

-(void)updateNick:(NSString *)nick oldNick:(NSString *)oldNick cid:(int)cid bid:(int)bid {
    @synchronized(_users) {
        User *user = [self getUser:oldNick cid:cid bid:bid];
        if(user) {
            user.nick = nick;
            user.old_nick = oldNick;
            [[_users objectForKey:@(bid)] removeObjectForKey:[oldNick lowercaseString]];
            [[_users objectForKey:@(bid)] setObject:user forKey:[nick lowercaseString]];
        }
    }
}

-(void)updateDisplayName:(NSString *)displayName nick:(NSString *)nick cid:(int)cid {
    @synchronized(_users) {
        for(NSDictionary *d in _users.allValues) {
            for(User *u in d.allValues) {
                if(u.cid == cid && [u.nick isEqualToString:nick]) {
                    [[_users objectForKey:@(u.bid)] removeObjectForKey:u.lowercase_nick];
                    u.display_name = displayName;
                    [[_users objectForKey:@(u.bid)] setObject:u forKey:u.lowercase_nick];
                    break;
                }
            }
        }
    }
}

-(void)updateAway:(int)away msg:(NSString *)msg nick:(NSString *)nick cid:(int)cid {
    @synchronized(_users) {
        for(NSDictionary *buffer in _users.allValues) {
            User *user = [buffer objectForKey:[nick lowercaseString]];
            if(user && user.cid == cid) {
                user.away = away;
                user.away_msg = msg;
            }
        }
    }
}

-(void)updateAway:(int)away nick:(NSString *)nick cid:(int)cid {
    @synchronized(_users) {
        for(NSDictionary *buffer in _users.allValues) {
            User *user = [buffer objectForKey:[nick lowercaseString]];
            if(user && user.cid == cid) {
                user.away = away;
            }
        }
    }
}

-(void)updateHostmask:(NSString *)hostmask nick:(NSString *)nick cid:(int)cid bid:(int)bid {
    @synchronized(_users) {
        User *user = [self getUser:nick cid:cid bid:bid];
        if(user)
            user.hostmask = hostmask;
    }
}

-(void)updateMode:(NSString *)mode nick:(NSString *)nick cid:(int)cid bid:(int)bid {
    @synchronized(_users) {
        User *user = [self getUser:nick cid:cid bid:bid];
        if(user)
            user.mode = mode;
    }
}
@end
