//
//  RMMultiMBTilesTileSource.h
//  
//
//  Created by Malcolm Toon on 5/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RMTileSource.h"

@class RMFractalTileProjection;
@class FMDatabase;

#define kMBTilesDefaultTileSize 256
#define kMBTilesDefaultMinTileZoom 0
#define kMBTilesDefaultMaxTileZoom 18
#define kMBTilesDefaultLatLonBoundingBox ((RMSphericalTrapezium){ .northeast = { .latitude =  90, .longitude =  180 }, \
.southwest = { .latitude = -90, .longitude = -180 } })


@interface RMMultiMBTilesTileSource : NSObject <RMTileSource> {
    RMFractalTileProjection *tileProjection;
	NSMutableDictionary *dbDictionary;
	float _minZoom;
	float _maxZoom;
	NSString *_cacheName;
	NSMutableArray *databaseNames;
	
	NSString *shortName;
	NSString *longDescription;
	NSString *shortAttribution;
	NSString *longAttribution;
	bool hasBaseLayer;
	NSString *baseLayerName;
}

@property (copy, nonatomic) NSString *baseLayerName;
@property (copy, nonatomic) NSString *shortName;
@property (copy, nonatomic) NSString *longDescription;
@property (copy, nonatomic) NSString *shortAttribution;
@property (copy, nonatomic) NSString *longAttribution;



-(id)initWithArray:(NSArray *)fileArray cacheName:(NSString *)cacheName;
-(void)closeAllDatabases;
-(void)addDatabase:(NSString *)databaseFilename;
-(RMTileImage *)getTileImageFrom:(FMDatabase *)db atZoom:(int)zoom atCol:(int)col atRow:(int)row aTile:(RMTile)tile;
-(void)setBaseLayer:(NSString *)databaseFilename;
-(void)setReverseTiles:(NSString *)databaseFilename;

- (int)tileSideLength;
- (void)setTileSideLength:(NSUInteger)aTileSideLength;
- (RMTileImage *)tileImage:(RMTile)tile;
- (NSString *)tileURL:(RMTile)tile;
- (NSString *)tileFile:(RMTile)tile;
- (NSString *)tilePath;
- (id <RMMercatorToTileProjection>)mercatorToTileProjection;
- (RMProjection *)projection;
- (float)minZoom;
- (float)maxZoom;
- (void)setMinZoom:(NSUInteger)aMinZoom;
- (void)setMaxZoom:(NSUInteger)aMaxZoom;
- (RMSphericalTrapezium)latitudeLongitudeBoundingBox;
- (void)didReceiveMemoryWarning;
- (NSString *)uniqueTilecacheKey;
- (void)removeAllCachedImages;

@end
