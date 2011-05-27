//
//  RMMultiMBTilesTileSource.m
//  
//
//  Created by Malcolm Toon on 5/21/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RMMultiMBTilesTileSource.h"
#import "RMTileImage.h"
#import "RMProjection.h"
#import "RMFractalTileProjection.h"
#import "FMDatabase.h"


@implementation RMMultiMBTilesTileSource

@synthesize shortName, longDescription, shortAttribution, longAttribution;
@synthesize baseLayerName;

-(void)closeAllDatabases {
	
	int c = [databaseNames count];
	for (int i=0; i < c; i++) {
		NSString *dbName = [databaseNames objectAtIndex:i];
		NSDictionary *d = [dbDictionary objectForKey:dbName];
		FMDatabase *db = [d objectForKey:@"database"];
		[db close];
	}
	
}

-(void)addDatabase:(NSString *)databaseFilename {
	/*
	 DB Format:
	
	 databaseFilename
		db: FMDatabase object
	    reverse-tiles: T/F
	    1: Zoom Level (as NSNumber) (NSMutableDictionary)
			mincol: NSNumber (int)
	        maxcol: NSNumber (int)
	        minrow: NSNumber (int)
	        maxrow: NSNumber (int)
	    .
	    . 
	    12
	 
	 */
	
	NSURL *tilesURL = [NSURL fileURLWithPath:[[NSBundle mainBundle]
											  pathForResource:databaseFilename 
											  ofType:@"mbtiles"]];

	FMDatabase *db = [[FMDatabase databaseWithPath:[tilesURL relativePath]] retain];
    
    if (![db open]) return;
	
	NSMutableDictionary *dbEntry = [[NSMutableDictionary alloc] init];
	[dbEntry setObject:@"F" forKey:@"base-layer"];
	[dbEntry setObject:@"F" forKey:@"reverse-tiles"];
	[dbEntry setObject:db forKey:@"database"];
	
	[dbDictionary setObject:dbEntry forKey:databaseFilename];
	[databaseNames addObject:databaseFilename];
	
	// Get all the zoom levels and min/max for each
	FMResultSet *results = [db executeQuery:@"select distinct zoom_level from tiles"];

//    if ([db hadError])
//        return [RMTileImage dummyTile:tile];
    
    while ([results next]) {
		int zl = [results intForColumn:@"zoom_level"];
		if (zl < _minZoom) {
			_minZoom = zl;
		}
		if (zl > _maxZoom) {
			_maxZoom = zl;
		}
		
		FMResultSet *minMaxResults = [db executeQuery:@"select max(tile_column) as maxcol, max(tile_row) as maxrow, min(tile_column) as mincol, min(tile_row) as minrow from tiles where zoom_level = ?", [NSNumber numberWithInt:zl]];
		if ([minMaxResults next]) {
			// 
			int minCol = [minMaxResults intForColumn:@"mincol"];
			int maxCol = [minMaxResults intForColumn:@"maxcol"];
			int minRow = [minMaxResults intForColumn:@"minrow"];
			int maxRow = [minMaxResults intForColumn:@"maxrow"];
			
			// ZoomLevel Dictionary
			NSMutableDictionary *zoomDictionary = [[NSMutableDictionary alloc] init];
			[zoomDictionary setObject:[NSNumber numberWithInt:minCol] forKey:@"minCol"];
			[zoomDictionary setObject:[NSNumber numberWithInt:maxCol] forKey:@"maxCol"];
			[zoomDictionary setObject:[NSNumber numberWithInt:minRow] forKey:@"minRow"];
			[zoomDictionary setObject:[NSNumber numberWithInt:maxRow] forKey:@"maxRow"];
			
			
			[dbEntry setObject:zoomDictionary forKey:[NSNumber numberWithInt:zl]];
			
			NSLog(@"Adding Zoom Level for %@, %i, %i, %i, %i, %i", databaseFilename, zl, minCol, maxCol, minRow, maxRow);
		}
		[minMaxResults close];
	}
	
	[results close];
	
	
}

-(NSMutableDictionary *)dictionaryForFile:(NSString *)aFilename {
	NSMutableDictionary *d = [dbDictionary objectForKey:aFilename];
	return d;
}

-(void)setBaseLayer:(NSString *)databaseFilename {
	// Find the db entry with the datbase filename and set it's "base-layer" to "T"
	NSMutableDictionary *d = [self dictionaryForFile:databaseFilename];
	if (!d) {
		return;
	}
	hasBaseLayer = YES;
	self.baseLayerName = databaseFilename;
	[d setObject:@"T" forKey:@"base-layer"];
}

-(void)setReverseTiles:(NSString *)databaseFilename {
	// This will reverse how the tiles are loaded
	// Find the db entry with the datbase filename and set it's "base-layer" to "T"
	NSMutableDictionary *d = [self dictionaryForFile:databaseFilename];
	if (!d) {
		return;
	}
	
	[d setObject:@"T" forKey:@"reverse-tiles"];
		
}



-(id)initWithArray:(NSArray *)fileArray cacheName:(NSString *)cacheName {
	if ( ! [super init])
		return nil;
	
	hasBaseLayer = NO;
	_minZoom = 100000;
	_maxZoom = 0;
	_cacheName = [cacheName copy];
	
	tileProjection = [[RMFractalTileProjection alloc] initFromProjection:[self projection] 
                                                          tileSideLength:kMBTilesDefaultTileSize 
                                                                 maxZoom:kMBTilesDefaultMaxTileZoom 
                                                                 minZoom:kMBTilesDefaultMinTileZoom];

	// Load all of the databases
	databaseNames = [[NSMutableArray alloc] init];

	dbDictionary = [[NSMutableDictionary alloc] init];
	
	for (int i=0; i < [fileArray count]; i++) {
		NSString *s = [fileArray objectAtIndex:i];
		[self addDatabase:s];
	}

    
	return self;
	
}


- (void)dealloc
{
	[tileProjection release];
	[self closeAllDatabases];
    [dbDictionary release];
	[databaseNames release];    
	[super dealloc];
}

- (int)tileSideLength {
	return tileProjection.tileSideLength;
}

- (void)setTileSideLength:(NSUInteger)aTileSideLength {
	[tileProjection setTileSideLength:aTileSideLength];
}

-(NSData *)getTileDataFrom:(FMDatabase *)db atZoom:(int)zoom atCol:(int)col atRow:(int)row {
	FMResultSet *singleImageResult = [db executeQuery:@"select tile_data from tiles where zoom_level = ? and tile_column = ? and tile_row = ?", 
									  [NSNumber numberWithFloat:zoom], 
									  [NSNumber numberWithFloat:col], 
									  [NSNumber numberWithFloat:row]];
	if ([db hadError]) {
		return nil;
	} else {
		if ([singleImageResult next]) {
			NSData *data = [singleImageResult dataForColumn:@"tile_data"];
			[singleImageResult close];
			return data;
		} else {
			return nil;
		}
	}
	
}

-(RMTileImage *)getTileImageFrom:(FMDatabase *)db atZoom:(int)zoom atCol:(int)col atRow:(int)row aTile:(RMTile)tile {
	RMTileImage *image = nil;
	
	NSData *data = [self getTileDataFrom:db atZoom:zoom atCol:col atRow:row];
	if (!data) {
		image = [RMTileImage dummyTile:tile];
	} else {
		image = [RMTileImage imageForTile:tile withData:data];
	}
	
	return image;
}

- (RMTileImage *)tileImage:(RMTile)tile {
    NSInteger zoom = tile.zoom;
    NSInteger x    = tile.x;
    NSInteger y    = pow(2, zoom) - tile.y - 1;

	
	// Get all of the various databases that can match this
	NSMutableArray *matchingDBArray = [[NSMutableArray alloc] init];
	int c = [databaseNames count];
	for (int i=0; i < c; i++) {
		NSString *dbName = [databaseNames objectAtIndex:i];
		NSDictionary *d = [dbDictionary objectForKey:dbName];
		NSDictionary *zoomD = [d objectForKey:[NSNumber numberWithInt:zoom]];
		if (zoomD) {
			NSNumber *minColn = [zoomD objectForKey:@"minCol"];
			NSNumber *maxColn = [zoomD objectForKey:@"maxCol"];
			NSNumber *minRown = [zoomD objectForKey:@"minRow"];
			NSNumber *maxRown = [zoomD objectForKey:@"maxRow"];
			
			int minCol = [minColn intValue];
			int maxCol = [maxColn intValue];
			int minRow = [minRown intValue];
			int maxRow = [maxRown intValue];
			
			if ([[d objectForKey:@"reverse-tiles"] isEqualToString:@"T"]) {
				y = tile.y;
			} else {
				y = pow(2, zoom) - tile.y - 1;
			}
						
			if ((x >= minCol) && (x <= maxCol) && (y >= minRow) && (y <= maxRow)) {
				NSLog(@"Found match: %@ for z: %i  x: %i  y: %i", dbName, zoom, x, y);
				// Check to see if it's a base layer and if so, insert at the beginning
				if ([[d objectForKey:@"base-layer"] isEqualToString:@"T"]) {
					NSLog(@"Current layer is baselayer... inserting instead of adding");
					[matchingDBArray insertObject:d atIndex:0];
				} else {
					[matchingDBArray addObject:d];
				}
			}
		}
	}
		
	// Get all of the images
	RMTileImage *image = nil;
	
	if ([matchingDBArray count] == 0) {
        image = [RMTileImage dummyTile:tile];
	} else if ([matchingDBArray count] == 1) {
		// Optimized for the single use case
		NSDictionary *singleImageDict = [matchingDBArray objectAtIndex:0];
		FMDatabase *singleImageDB = [singleImageDict objectForKey:@"database"];
		if ([[singleImageDict objectForKey:@"reverse-tiles"] isEqualToString:@"T"]) {
			y = tile.y;
		} else {
			y = pow(2, zoom) - tile.y - 1;
		}
		image = [self getTileImageFrom:singleImageDB atZoom:zoom atCol:x atRow:y aTile:tile];
	} else {
		// Iterates the list and creates a combined tile
		// NSMutableArray *tileImageArray = [[NSMutableArray alloc] init];
		
		// Create te 
		CGRect area = CGRectMake(0,0,256,256);
		UIGraphicsBeginImageContext(area.size);
		CGContextRef context = UIGraphicsGetCurrentContext();
		CGContextRetain(context);
		
		// mirroring context
		CGContextTranslateCTM(context, 0.0, area.size.height);
		CGContextScaleCTM(context, 1.0, -1.0);
		
		for (int j=0; j < [matchingDBArray count]; j++) {
			NSDictionary *d = [matchingDBArray objectAtIndex:j];
			FMDatabase *db = [d objectForKey:@"database"];

			if ([[d objectForKey:@"reverse-tiles"] isEqualToString:@"T"]) {
				y = tile.y;
			} else {
				y = pow(2, zoom) - tile.y - 1;
			}
			
			NSData *imageData = [self getTileDataFrom:db atZoom:zoom atCol:x atRow:y];
			UIImage *tempImage = [[UIImage alloc] initWithData:imageData];
			
			CGContextBeginTransparencyLayer(context, nil);
			
			if (hasBaseLayer) {
				if ([[d objectForKey:@"base-layer"] isEqualToString:@"T"]) {
					CGContextSetAlpha( context, 1.0 );
				} else {
					CGContextSetAlpha( context, 1.0 );
				}
			} else {
				CGContextSetAlpha( context, 1.0 );
			}
					
			CGContextDrawImage(context, area, tempImage.CGImage);
			CGContextEndTransparencyLayer(context);
		}
		
		// get created image
		UIImage *finalImage = UIGraphicsGetImageFromCurrentImageContext();
		CGContextRelease(context);
		UIGraphicsEndImageContext();
		NSData *finalData = UIImagePNGRepresentation(finalImage);
		
		image = [RMTileImage imageForTile:tile withData:finalData];
		
	}
	
	return image;
}

- (NSString *)tileURL:(RMTile)tile
{
    return nil;
}

- (NSString *)tileFile:(RMTile)tile
{
    return nil;
}

- (NSString *)tilePath
{
    return nil;
}

- (id <RMMercatorToTileProjection>)mercatorToTileProjection
{
	return [[tileProjection retain] autorelease];
}

- (RMProjection *)projection
{
	return [RMProjection googleProjection];
}

- (float)minZoom
{
	return _minZoom;
}

- (float)maxZoom
{
	return _maxZoom;
}

- (void)setMinZoom:(NSUInteger)aMinZoom
{
    [tileProjection setMinZoom:aMinZoom];
}

- (void)setMaxZoom:(NSUInteger)aMaxZoom
{
    [tileProjection setMaxZoom:aMaxZoom];
}

- (RMSphericalTrapezium)latitudeLongitudeBoundingBox
{
    return kMBTilesDefaultLatLonBoundingBox;
}

- (void)didReceiveMemoryWarning
{
    NSLog(@"*** didReceiveMemoryWarning in %@", [self class]);
}

- (NSString *)uniqueTilecacheKey {
	return _cacheName;
}

- (void)removeAllCachedImages
{
    NSLog(@"*** removeAllCachedImages in %@", [self class]);
}

@end