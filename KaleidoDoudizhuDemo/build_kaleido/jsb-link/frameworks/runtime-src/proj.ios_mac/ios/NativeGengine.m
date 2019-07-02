//
//  NativeGengine.m
//  KaleidoDoudizhuDemo-mobile
//
//  Created by on 2019/1/24.
//
#import "NativeGengine.h"

@interface NativeGengine ()

@property(nonatomic, strong)GengineNode *g_node;
@end

@implementation NativeGengine

+(instancetype)shareInstance {

    static NativeGengine* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc]init];
    });
    return instance;

}

+(void)clearCache {
    NSError *error = nil;
    GengineClearCache(&error);
}

+(BOOL)callNativeUIWithTitle:(NSString *) title andContent:(NSString *)content{
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:title message:content delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
    [alertView show];
    return true;
}

+(NSString*)createAccount:(NSString *)passphase{
    NSError *error = nil;
    GengineKeyStore *keystore = GengineNewKeyStore(GengineStandardScryptN, GengineStandardScryptP, &error);
    GengineMnemonicInfo *info = [keystore createAccount:passphase wordlistidx:GengineChineseSimplified error:&error];
    NSDictionary * dict = [NSDictionary dictionaryWithObjectsAndKeys:[info pubKey],@"pubKey",[info mnemonic],@"mnemonic",nil];
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:nil error:&error];
    NSString *string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

+(BOOL)deleteAccount:(NSString *) accountAddr withPassword:(NSString *) password {
    NSError *error = nil;
    GengineKeyStore *keystore = GengineNewKeyStore(GengineStandardScryptN, GengineStandardScryptP, &error);
    GengineAddress *addr = GengineNewAddressFromHex(accountAddr, &error);
    if (![keystore hasAddress:addr]) {
        return false;
    }
    GengineAccounts *accounts = [keystore getAccounts];
    int i;
    int count;
    for (i = 0, count = (int)[accounts size]; i < count; i = i + 1) {
        GengineAccount *account = [accounts get:i error:&error];
        GengineAddress *addr = [account getAddress];
        NSString *addrHex = [[addr getHex] lowercaseString];
        if ([[accountAddr lowercaseString] isEqualToString:addrHex]) {
            return [keystore deleteAccount:account passphrase:password error:&error];
        }
    }
    return false;
}

+(BOOL)unlockAccount:(NSString *) accountAddr withPassword:(NSString *)password {
    NSError *error = nil;
    GengineKeyStore *keystore = GengineNewKeyStore(GengineStandardScryptN, GengineStandardScryptP, &error);
    GengineAddress *addr = GengineNewAddressFromHex(accountAddr, &error);
    if (![keystore hasAddress:addr]) {
        return false;
    }
    GengineAccounts *accounts = [keystore getAccounts];
    int i;
    int count;
    for (i = 0, count = (int)[accounts size]; i < count; i = i + 1) {
        GengineAccount *account = [accounts get:i error:&error];
        GengineAddress *addr = [account getAddress];
        NSString *addrHex = [[addr getHex] lowercaseString];
        if ([[accountAddr lowercaseString] isEqualToString:addrHex]) {
            return [keystore unlock:account passphrase:password error:&error];
        }
    }
    return false;
}

+(NSString*)importAccount:(NSString *)mnemonic withPassword:(NSString *)password {
    NSError *error = nil;
    GengineKeyStore *keystore = GengineNewKeyStore(GengineStandardScryptN, GengineStandardScryptP, &error);
    NSString *pubkey = [keystore importAccount:mnemonic passphrase:password wordlistidx:GengineChineseSimplified error:&error];
    NSLog(@"importAccount return pubkey: %@, err: %@", pubkey, error);
    return pubkey;
}

+(NSString*)getAccounts {
    NSError *error = nil;
    GengineKeyStore *keystore = GengineNewKeyStore(GengineStandardScryptN, GengineStandardScryptP, &error);
    GengineAccounts *accounts = [keystore getAccounts];
    int i;
    int count;
    NSMutableArray *arr = [NSMutableArray array];
    for (i = 0, count = (int)[accounts size]; i < count; i = i + 1) {
        GengineAccount *account = [accounts get:i error:&error];
        GengineAddress *addr = [account getAddress];
        NSString *addrHex = [addr getHex];
        if ([keystore hasAddress:addr]) {
            [arr addObject:addrHex];
        }
    }
    NSData *data = [NSJSONSerialization dataWithJSONObject:arr options:nil error:&error];
    NSString *string = [[NSString alloc]initWithData:data encoding:NSUTF8StringEncoding];
    return string;
}

+(BOOL)startGameEngineWithAccount:(NSString *) account andPassword:(NSString *) password {
    NSError *error = nil;
    //GengineSetVerbosity(5);
    GengineNodeConfig *config = GengineNewNodeConfig();
    GengineEngineConfig *engineconfig = GengineNewEngineConfig();
    [engineconfig setUseAccountAddr:account];
    [engineconfig setUseAccountPassword:password];
    [NativeGengine shareInstance].g_node = GengineNewNode(config, engineconfig, &error);
    BOOL ret = [[NativeGengine shareInstance].g_node start:&error];
    NSLog(@"start return %i, %@, error: %d, %@", ret, [NativeGengine shareInstance].g_node, (int)error.code, error.description);
//    ret = [g_node stop:&error];
//    NSLog(@"stop return %i, error: %d", ret, (int)error.code);
    return ret;
}

+(BOOL)stopGameEngine {
    BOOL ret = NO;
    NSError *error = nil;
    if ([NativeGengine shareInstance].g_node != nil) {
//        NSLog(@"g_node: %@", g_node);
        ret = [[NativeGengine shareInstance].g_node stop:&error];
        NSLog(@"stop return %i, %@, error: %d", ret, [NativeGengine shareInstance].g_node, (int)error.code);
        [NativeGengine shareInstance].g_node = nil;
    }
    return ret;
}

+(BOOL)isRunning {
    return [NativeGengine shareInstance].g_node != nil;
}

+(void)openURL:(NSString *) url {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
}

+(long)getWSPort {
    return GengineGetLocalWSPort();
}

+(void)copyToClipboard:(NSString *) addr {
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = addr;
}

@end
