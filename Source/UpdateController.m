//
//  UpdateController.m
//  GPGPreferences
//
//  Created by Mento on 26.04.2013
//
//

#import <Libmacgpg/Libmacgpg.h>
#import "UpdateController.h"

@interface UpdateController()
@property (retain) SUUpdater *updater;
@property (assign) NSBundle *bundle;
@end


@implementation UpdateController
@synthesize updater;
NSMutableDictionary *tools;
/* tools[tool][key]. key is an of: 
 @"options"			GPGOptions*
 @"path"			NSString*
 @"infoPlist"		NSDictionary*
 @"canSendActions"	NSNumber*
 */



// Init, alloc etc.
+ (void)initialize {
#define DKEY @"domain"
#define PKEY @"path"
#define IKEY @"identifier"
	NSDictionary *toolInfos = @{
		@"macgpg2" :		@{DKEY : @"org.gpgtools.macgpg2.updater", PKEY : @"/usr/local/MacGPG2/libexec/MacGPG2_Updater.app"},
		@"gpgmail" :		@{DKEY : @[@"../Containers/com.apple.mail/Data/Library/Preferences/org.gpgtools.gpgmail", @"org.gpgtools.gpgmail"], PKEY : @[@"/Network/Library/Mail/Bundles/GPGMail.mailbundle", @"~/Library/Mail/Bundles/GPGMail.mailbundle", @"/Library/Mail/Bundles/GPGMail.mailbundle"]},
		@"gpgservices" :	@{DKEY : @"org.gpgtools.gpgservices", PKEY : @[@"~/Library/Services/GPGServices.service", @"/Library/Services/GPGServices.service"]},
		@"gka" :			@{DKEY : @"org.gpgtools.gpgkeychainaccess", IKEY : @"org.gpgtools.gpgkeychainaccess"},
		@"gpgprefs" :		@{DKEY : @"org.gpgtools.gpgpreferences", PKEY : @[@"~/Library/PreferencePanes/GPGPreferences.prefPane", @"/Library/PreferencePanes/GPGPreferences.prefPane"]}
		};
	
	tools = [[NSMutableDictionary alloc] initWithCapacity:toolInfos.count];
	
	
	NSString *prefDir = [NSHomeDirectory() stringByAppendingString:@"/Library/Preferences/"];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	for (NSString *tool in toolInfos) {
		NSMutableDictionary *toolDict = [NSMutableDictionary dictionary];
		NSDictionary *toolInfo = toolInfos[tool];
		
		
		// GPGOptions for every tool.
		id domains = toolInfo[DKEY]; //NSString or NSArray of NSStrings.
		NSString *domain = nil;
		
		if ([domains isKindOfClass:[NSArray class]]) {
			// Use the first plist, which exists.
			for (NSString *aDomain in domains) {
				NSString *path = [prefDir stringByAppendingFormat:@"%@.plist", aDomain];
				if ([fileManager fileExistsAtPath:path]) {
					domain = aDomain;
					break;
				}
			}
			if (!domain) {
				domain = domains[0];
			}
		} else {
			domain = domains;
		}
		
		GPGOptions *options = [GPGOptions new];
		options.standardDomain = domain;
		
		toolDict[@"options"] = options;
		[options release];
		
		
		// Paths to the tools.
		id paths = toolInfo[PKEY];
		if (!paths) {
			NSString *path = [[NSWorkspace sharedWorkspace] absolutePathForAppBundleWithIdentifier:toolInfo[IKEY]];
			paths = path ? @[path] : @[];
		} else if (![paths isKindOfClass:[NSArray class]]) {
			paths = @[paths];
		}
		
		for (NSString *path in paths) {
			NSString *plistPath = [[path stringByExpandingTildeInPath] stringByAppendingPathComponent:@"Contents/Info.plist"];
			if ([fileManager fileExistsAtPath:plistPath]) {
				toolDict[@"path"] = path;
				toolDict[@"infoPlist"] = [NSDictionary dictionaryWithContentsOfFile:plistPath];
				break;
			}
		}
		
		
		if ([tool isEqualToString:@"gpgprefs"]) {
			toolDict[@"canSendActions"] = @YES;
		}
		
		// Set the dict for the tool.
		tools[tool] = toolDict;
	}
}

- (id)init {
	if (!(self = [super init])) {
		return nil;
	}
	self.bundle = [NSBundle bundleForClass:[self class]];
	self.updater = [SUUpdater updaterForBundle:self.bundle];
	updater.delegate = self;
	
	return self;
}

- (void)dealloc {
	self.updater = nil;
	[super dealloc];
}


- (id)defaultsValueForKey:(NSString *)key forTool:(NSString *)tool {
	NSDictionary *toolDict = tools[tool];
	id value = [toolDict[@"options"] valueInStandardDefaultsForKey:key];

	if (!value) {
		value = toolDict[@"infoPlist"][key];
	}
	return value;
}


// Getter and setter.
- (id)valueForKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	NSString *tool = [self toolAndKey:&key forKeyPath:keyPath];
	GPGOptions *options = tools[tool][@"options"];
	
	if (!tool) {
		return [super valueForKeyPath:keyPath];
	}

	
	if ([key isEqualToString:@"CheckInterval"]) {
		id value = [self defaultsValueForKey:@"SUEnableAutomaticChecks" forTool:tool];
		
		if ([value respondsToSelector:@selector(boolValue)] && [value boolValue]) {
			value = [self defaultsValueForKey:@"SUScheduledCheckInterval" forTool:tool];
			return value ? value : @86400;
		}
		
		return @0;
	} else if ([key isEqualToString:@"UpdateType"]) {
		id value = [options valueInStandardDefaultsForKey:@"UpdateSource"];
		
		if ([value isEqualTo:@"stable"]) {
			return @0;
		} else if ([value isEqualTo:@"prerelease"]) {
			return @1;
		} else if ([value isEqualTo:@"nightly"]) {
			return @2;
		}
		
		NSDictionary *plist = tools[tool][@"infoPlist"];
		if (plist) {
			NSString *version = plist[@"CFBundleVersion"];
			if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]].length > 0) {
				return @2;
			} else if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
				return @1;
			}
		}
		
		return @0;
	} else if ([key isEqualToString:@"Installed"]) {
		return @(!!tools[tool][@"path"]);
	} else if ([key isEqualToString:@"Path"]) {
		return tools[tool][@"path"];
	} else if ([key isEqualToString:@"CanSendActions"]) {
		return tools[tool][@"canSendActions"];
	} else if ([key isEqualToString:@"buildNumberDescription"]) {
		NSDictionary *plist = tools[tool][@"infoPlist"];
		if (!plist) {
			return nil;
		}
		
		return [NSString stringWithFormat:[self.bundle localizedStringForKey:@"BUILD: %@" value:nil table:nil], plist[@"CFBundleVersion"]];
	} else if ([key isEqualToString:@"versionDescription"]) {
		NSDictionary *plist = tools[tool][@"infoPlist"];
		if (!plist) {
			return nil;
		}

		return [NSString stringWithFormat:[self.bundle localizedStringForKey:@"VERSION: %@" value:nil table:nil], plist[@"CFBundleShortVersionString"]];
	} else if ([key isEqualToString:@"image"]) {
		NSImage *image = nil;
		if (tools[tool][@"path"]) {
			image = tools[tool][@"image"];
			if (!image) {
				image = [self.bundle imageForResource:tool];
				tools[tool][@"image"] = image;
			}
		} else {
			image = tools[tool][@"image-gray"];
			if (!image) {
				image = [self.bundle imageForResource:[tool stringByAppendingString:@"-gray"]];
				tools[tool][@"image-gray"] = image;
			}
		}
		return image;
	} else if ([key isEqualToString:@"text-color"]) {
		return tools[tool][@"path"] ? [NSColor blackColor] : [NSColor grayColor];
	}
	
	
	
	return [options valueInStandardDefaultsForKey:key];
}


- (void)setValue:(id)value forKeyPath:(NSString *)keyPath {
	NSString *key = nil;
	NSString *tool = [self toolAndKey:&key forKeyPath:keyPath];
	GPGOptions *options = tools[tool][@"options"];
	
	if (!options) {
		[super setValue:value forKeyPath:keyPath];
		return;
	}

	int intValue = 0;
	if ([value respondsToSelector:@selector(intValue)]) {
		intValue = [value intValue];
	}
	
	if ([key isEqualToString:@"CheckInterval"]) {
		if (intValue > 0) {
			[options setValueInStandardDefaults:value forKey:@"SUScheduledCheckInterval"];
			[options setValueInStandardDefaults:@YES forKey:@"SUEnableAutomaticChecks"];
		} else {
			[options setValueInStandardDefaults:nil forKey:@"SUScheduledCheckInterval"];
			[options setValueInStandardDefaults:@NO forKey:@"SUEnableAutomaticChecks"];
		}
	} else if ([key isEqualToString:@"UpdateType"]) {
		NSString *type;
		switch (intValue) {
			case 1:
				type = @"prerelease";
				break;
			case 2:
				type = @"nightly";
				break;
			default:
				type = @"stable";
				break;
		}
		[options setValueInStandardDefaults:type forKey:@"UpdateSource"];
	} else {
		[options setValueInStandardDefaults:value forKey:key];
	}
}




// Actions
- (void)checkForUpdatesForTool:(NSString *)tool{
	if ([tool isEqualToString:@"gpgprefs"]) {
		[updater checkForUpdates:self];
	}
}



// Helper and other methods.
- (NSString *)toolAndKey:(NSString **)key forKeyPath:(NSString *)keyPath {
	NSRange range = [keyPath rangeOfString:@"."];
	if (range.length == 0) {
		return nil;
	}
	*key = [keyPath substringFromIndex:range.location + 1];
	
	return [keyPath substringToIndex:range.location];
}

- (id)valueForKey:(NSString *)key {
	if (tools[key]) {
		//Prevent valueForUndefinedKey.
		return key;
	}
	return [super valueForKey:key];
}



// For own Sparkle.
- (NSString *)feedURLStringForUpdater:(SUUpdater *)updater {
	NSString *updateSourceKey = @"UpdateSource";
	NSBundle *bundle = self.bundle;
	
	NSString *feedURLKey = @"SUFeedURL";
	NSString *appcastSource = [[GPGOptions sharedOptions] stringForKey:updateSourceKey];
	if ([appcastSource isEqualToString:@"nightly"]) {
		feedURLKey = @"SUFeedURL_nightly";
	} else if ([appcastSource isEqualToString:@"prerelease"]) {
		feedURLKey = @"SUFeedURL_prerelease";
	} else if (![appcastSource isEqualToString:@"stable"]) {
		NSString *version = [bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
		if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"nN"]].length > 0) {
			feedURLKey = @"SUFeedURL_nightly";
		} else if ([version rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"abAB"]].length > 0) {
			feedURLKey = @"SUFeedURL_prerelease";
		}
	}
	
	NSString *appcastURL = [bundle objectForInfoDictionaryKey:feedURLKey];
	if (!appcastURL) {
		appcastURL = [bundle objectForInfoDictionaryKey:@"SUFeedURL"];
	}
	return appcastURL;
}


@end
