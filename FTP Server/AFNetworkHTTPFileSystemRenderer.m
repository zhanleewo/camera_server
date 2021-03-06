//
//  AFNetworkHTTPFileSystemRenderer.m
//  FTP Server
//
//  Created by Keith Duncan on 12/12/2012.
//  Copyright (c) 2012 Keith Duncan. All rights reserved.
//

#import "AFNetworkHTTPFileSystemRenderer.h"

#import "CameraServer-Functions.h"

@interface AFNetworkHTTPFileSystemRenderer ()
@property (retain, nonatomic) id <AFVirtualFileSystem> fileSystem;
@end

@implementation AFNetworkHTTPFileSystemRenderer

@synthesize fileSystem=_fileSystem;

- (id)initWithFileSystem:(id <AFVirtualFileSystem>)fileSystem {
	self = [self init];
	if (self == nil) {
		return nil;
	}
	
	_fileSystem = [fileSystem retain];
	
	return self;
}

- (void)dealloc {
	[_fileSystem release];
	
	[super dealloc];
}

- (CFHTTPMessageRef)networkServer:(AFHTTPServer *)server renderResourceForRequest:(CFHTTPMessageRef)request {
	NSString *requestMethod = [NSMakeCollectable(CFHTTPMessageCopyRequestMethod(request)) autorelease];
	
	NSSet *allowedMethods = [NSSet setWithObjects:AFHTTPMethodHEAD, AFHTTPMethodGET, nil];
	if (![allowedMethods containsObject:requestMethod]) {
		return NULL;
	}
	
	NSURL *requestURL = [NSMakeCollectable(CFHTTPMessageCopyRequestURL(request)) autorelease];
	
#warning should be able to serve a subpath of the root URL namespace from the hierarchical file system, could be done with a prefix at initialisation time, or have a path prefix to omit / path suffix to serve passed with the request?
	NSString *requestPath = [requestURL path];
	
	AFVirtualFileSystemRequestRead *readRequest = [[[AFVirtualFileSystemRequestRead alloc] initWithPath:requestPath] autorelease];
	
	NSError *readError = nil;
	AFVirtualFileSystemResponse *readResponse = [self.fileSystem executeRequest:readRequest error:&readError];
	if (readResponse == nil) {
		return NULL;
	}
	
	BOOL justCheckExistance = [requestMethod isEqualToString:AFHTTPMethodHEAD];
	if (justCheckExistance) {
		return AFHTTPMessageMakeResponseWithCode(AFHTTPStatusCodeOK);
	}
	
	if (readResponse.node.nodeType == AFVirtualFileSystemNodeTypeContainer) {
		return [self _renderContainerResponse:readResponse];
	}
	else if (readResponse.node.nodeType == AFVirtualFileSystemNodeTypeObject) {
		return [self _renderObjectResponse:readResponse];
	}
	
	return NULL;
}

- (CFHTTPMessageRef)_renderContainerResponse:(AFVirtualFileSystemResponse *)containerResponse {
	return NULL;
}

- (CFHTTPMessageRef)_renderObjectResponse:(AFVirtualFileSystemResponse *)objectResponse {
	/*
		Note
		
		should support setting the body of the response to the stream as in NSURLRequest so that we don't have to concatenate the body here requiring synchronous read from the file system
	 */
	
	NSInputStream *objectStream = objectResponse.body;
	NSData *bodyData = CameraServerContentsOfInputStream(objectStream, NULL);
	if (bodyData == nil) {
		return NULL;
	}
	
	AFHTTPStatusCode statusCode = AFHTTPStatusCodeOK;
	CFHTTPMessageRef response = AFHTTPMessageMakeResponseWithCode(statusCode);
	
	NSString *contentType = CameraServerContentTypeForFileSystemPath(objectResponse.node.absolutePath);
	CFHTTPMessageSetHeaderFieldValue(response, (CFStringRef)AFHTTPMessageContentTypeHeader, (CFStringRef)contentType);
	
	CFHTTPMessageSetBody(response, (CFDataRef)bodyData);
	
	return response;
}

@end
