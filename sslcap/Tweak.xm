// SSLCap — iOS tweak для перехоплення HTTPS у Gmail/IG/FB.
//
// Етап 1 (цей файл):
//   - хук на NSURLSession.dataTaskWithRequest:completionHandler:
//   - хук на delegate didReceiveData: (щоб бачити відповіді)
//   - лог у syslog через NSLog — побачимо через `idevicesyslog | grep SSLCap`.
//
// Етап 2 (далі):
//   - GmailDumper.m — писати у /var/mobile/Documents/gmail_dump/<timestamp>.json
//   - кореляція task↔request через objc_setAssociatedObject

#import <Foundation/Foundation.h>

// ───────────────────────────────── helpers ─────────────────────────────────

static NSString *SSLCapBundleID(void) {
    return [[NSBundle mainBundle] bundleIdentifier] ?: @"unknown";
}

// Коротко показує тіло — base64 якщо бінарне, інакше UTF-8.
static NSString *SSLCapSnippet(NSData *data, NSUInteger max) {
    if (!data || data.length == 0) return @"<empty>";
    NSData *slice = (data.length > max) ? [data subdataWithRange:NSMakeRange(0, max)] : data;
    NSString *s = [[NSString alloc] initWithData:slice encoding:NSUTF8StringEncoding];
    if (s) return (data.length > max) ? [s stringByAppendingString:@"…"] : s;
    return [NSString stringWithFormat:@"<binary %lu bytes>", (unsigned long)data.length];
}

// ───────────────────────────────── NSURLSession ────────────────────────────

%hook NSURLSession

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request
                            completionHandler:(void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    NSLog(@"[SSLCap][%@] REQ  %@ %@  hdr=%lu  body=%@",
          SSLCapBundleID(),
          request.HTTPMethod ?: @"GET",
          request.URL.absoluteString ?: @"<nil>",
          (unsigned long)request.allHTTPHeaderFields.count,
          SSLCapSnippet(request.HTTPBody, 256));

    if (completionHandler) {
        void (^wrapped)(NSData *, NSURLResponse *, NSError *) =
          ^(NSData *data, NSURLResponse *resp, NSError *err) {
            NSHTTPURLResponse *http = [resp isKindOfClass:[NSHTTPURLResponse class]]
                                        ? (NSHTTPURLResponse *)resp : nil;
            NSLog(@"[SSLCap][%@] RSP  %ld  %@  body=%@  err=%@",
                  SSLCapBundleID(),
                  (long)http.statusCode,
                  request.URL.absoluteString ?: @"<nil>",
                  SSLCapSnippet(data, 256),
                  err.localizedDescription ?: @"-");
            completionHandler(data, resp, err);
          };
        return %orig(request, wrapped);
    }
    return %orig;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request {
    NSLog(@"[SSLCap][%@] REQ* %@ %@  (delegate-style, response piped through delegate hooks)",
          SSLCapBundleID(),
          request.HTTPMethod ?: @"GET",
          request.URL.absoluteString ?: @"<nil>");
    return %orig;
}

%end

// ─────────────────────── didReceiveData (delegate-style) ───────────────────
//   На багатьох апках (Gmail теж) використовується delegate-варіант без completion
//   handler. Ці хуки ловлять відповідь ЧЕРЕЗ клас-протокол NSURLSessionDataDelegate.
//   Робимо це через runtime-swizzle всього протокольного callback'у в ЛЮБОМУ делегаті.

#import <objc/runtime.h>

static void sslcap_didReceiveData(id self, SEL _cmd,
                                  NSURLSession *session,
                                  NSURLSessionDataTask *dataTask,
                                  NSData *data)
{
    NSURL *url = dataTask.currentRequest.URL ?: dataTask.originalRequest.URL;
    NSLog(@"[SSLCap][%@] CHK  %@  chunk=%lu  head=%@",
          SSLCapBundleID(),
          url.absoluteString ?: @"<nil>",
          (unsigned long)data.length,
          SSLCapSnippet(data, 128));

    // Викликаємо оригінал, якщо він був (збережений як sslcap_orig_<class>).
    IMP orig = (IMP)objc_getAssociatedObject([self class], @selector(sslcap_didReceiveData_orig));
    if (orig) {
        ((void (*)(id, SEL, id, id, id))orig)(self, _cmd, session, dataTask, data);
    }
}

%ctor {
    @autoreleasepool {
        NSLog(@"[SSLCap] loaded in %@  (pid=%d, exec=%@)",
              SSLCapBundleID(),
              getpid(),
              [[NSProcessInfo processInfo] processName]);

        // Етап 1: тільки позначка завантаження. Delegate-swizzle робитимемо на Етапі 2
        //         прицільно (коли знаємо конкретні класи Gmail — class-dump IPA).
    }
}
