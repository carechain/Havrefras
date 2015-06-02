#import "OMHSerializer.h"
#import "NSDate+RFC3339.h"
#import <ObjectiveSugar/ObjectiveSugar.h>
#import "OMHWorkoutEnumMap.h"

@interface OMHSerializer()
@property (nonatomic, retain) HKSample* sample;
+ (NSDictionary*)typeIdentifiersToClasses;
+ (BOOL)canSerialize:(HKSample*)sample error:(NSError**)error;
+ (NSException*)unimplementedException;
@end


@implementation OMHSerializer

+ (NSDictionary*)typeIdentifiersToClasses {
  static NSDictionary* typeIdsToClasses = nil;
  if (typeIdsToClasses == nil) {
    typeIdsToClasses = @{
      HKQuantityTypeIdentifierHeight : @"OMHSerializerHeight",
      HKQuantityTypeIdentifierBodyMass : @"OMHSerializerWeight",
      HKQuantityTypeIdentifierStepCount : @"OMHSerializerStepCount",
      HKQuantityTypeIdentifierHeartRate : @"OMHSerializerHeartRate",
      HKQuantityTypeIdentifierBloodGlucose : @"OMHSerializerBloodGlucose",
      HKQuantityTypeIdentifierActiveEnergyBurned: @"OMHSerializerEnergyBurned",
      HKQuantityTypeIdentifierBodyMassIndex: @"OMHSerializerBodyMassIndex",
      HKCategoryTypeIdentifierSleepAnalysis : @"OMHSerializerSleepAnalysis",
      HKCorrelationTypeIdentifierBloodPressure: @"OMHSerializerBloodPressure",
      HKQuantityTypeIdentifierDietaryBiotin: @"OMHSerializerGenericQuantitySample",
      HKQuantityTypeIdentifierInhalerUsage: @"OMHSerializerGenericQuantitySample",
      HKCorrelationTypeIdentifierFood: @"OMHSerializerGenericCorrelation",
      HKWorkoutTypeIdentifier: @"OMHSerializerGenericWorkout"
    };
  }
  return typeIdsToClasses;
}

+ (NSArray*)supportedTypeIdentifiers {
  return [[self typeIdentifiersToClasses] allKeys];
}

+ (BOOL)canSerialize:(HKSample*)sample error:(NSError**)error {
  @throw [self unimplementedException];
}

- (id)initWithSample:(HKSample*)sample {
  self = [super init];
  if (self) {
    _sample = sample;
  } else {
    return nil;
  }
  return self;
}

- (NSString*)jsonForSample:(HKSample*)sample error:(NSError**)error {
    NSParameterAssert(sample);
    // first, verify we support the sample type
    NSArray* supportedTypeIdentifiers = [[self class] supportedTypeIdentifiers];
    NSString* sampleTypeIdentifier = sample.sampleType.identifier;
    if (![supportedTypeIdentifiers includes:sampleTypeIdentifier]) {
        if (error) {
            NSString* errorMessage =
            [NSString stringWithFormat: @"Unsupported HKSample type: %@",
             sampleTypeIdentifier];
            NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : errorMessage };
            *error = [NSError errorWithDomain: OMHErrorDomain
                                         code: OMHErrorCodeUnsupportedType
                                     userInfo: userInfo];
        }
        return nil;
    }
    // if we support it, select appropriate subclass for sample
    NSString* serializerClassName = [[self class] typeIdentifiersToClasses][sampleTypeIdentifier];
    //For sleep analysis, the OMH schema does not capture an 'inBed' state, so if that value is set we need to use a generic category serializer
    //otherwise, it defaults to using the OMH schema for the 'asleep' state.
    if ([sampleTypeIdentifier isEqualToString:HKCategoryTypeIdentifierSleepAnalysis]){
        HKCategorySample* categorySample = (HKCategorySample*)sample;
        if(categorySample.value == 0){
            serializerClassName = @"OMHSerializerGenericCategorySample";
        }
    }
    Class serializerClass = NSClassFromString(serializerClassName);
    // subclass verifies it supports sample's values
    if (![serializerClass canSerialize:sample error:error]) {
        return nil;
    }
    // instantiate a serializer
    OMHSerializer* serializer = [[serializerClass alloc] initWithSample:sample];
    NSData* jsonData =
    [NSJSONSerialization dataWithJSONObject:[serializer data]
                                    options:NSJSONWritingPrettyPrinted
                                      error:error];
    if (!jsonData) {
        return nil; // return early if JSON serialization failed
    }
    NSString* jsonString = [[NSString alloc] initWithData:jsonData
                                                 encoding:NSUTF8StringEncoding];
    return jsonString;
}

+ (NSString*)parseUnitFromQuantity:(HKQuantity*)quantity{
    NSString *quantityDescription = [quantity description];
    NSArray *array = [quantityDescription componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    //array = [array filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"SELF != ''"]];
    return [array objectAtIndex:1];
}

+ (NSDictionary*) populateTimeFrameProperty:(NSDate*)startDate endDate:(NSDate*)endDate{
    if ([startDate isEqualToDate:endDate]){
        return @{
                 @"date_time":[startDate RFC3339String]
                 };
    }
    else{
        return  @{
                  @"time_interval": @{
                                        @"start_date_time": [startDate RFC3339String],
                                        @"end_date_time": [endDate RFC3339String]
                                    }
                };
        
    }

}

+ (NSArray*) serializeMetadataArray:(NSDictionary*)metadata{
    NSMutableArray *serializedArray = [NSMutableArray new];
    for (id key in metadata) {
        [serializedArray addObject:@{@"key":key,@"value":[metadata valueForKey:key]}];
    }
    return [serializedArray copy];
}

#pragma mark - Private

- (id)data {
  return @{
    @"header": @{
      @"id": self.sample.UUID.UUIDString,
      @"creation_date_time": [self.sample.startDate RFC3339String],
      @"schema_id": @{
        @"namespace": @"omh",
        @"name": [self schemaName],
        @"version": [self schemaVersion]
      },
    },
    @"body": [self bodyData]
  };
}

- (NSString*)schemaName {
  @throw [[self class] unimplementedException];
}

- (NSString*)schemaVersion {
  @throw [[self class] unimplementedException];
}

- (id)bodyData {
  @throw [[self class] unimplementedException];
}

+ (NSException*)unimplementedException {
  return [NSException exceptionWithName:NSInternalInconsistencyException
                                 reason:[NSString stringWithFormat:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)]
                               userInfo:nil];
}

@end

@interface OMHSerializerStepCount : OMHSerializer; @end;
@implementation OMHSerializerStepCount
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  HKUnit* unit = [HKUnit unitFromString:@"count"];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"step_count": [NSNumber numberWithDouble:value],
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"step-count";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerHeight : OMHSerializer; @end;
@implementation OMHSerializerHeight
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  NSString* unitString = @"cm";
  HKUnit* unit = [HKUnit unitFromString:unitString];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"body_height": @{
      @"value": [NSNumber numberWithDouble:value],
      @"unit": unitString
    },
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"body-height";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerWeight : OMHSerializer; @end;
@implementation OMHSerializerWeight
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  NSString* unitString = @"lb";
  HKUnit* unit = [HKUnit unitFromString:unitString];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"body_weight": @{
      @"value": [NSNumber numberWithDouble:value],
      @"unit": unitString
    },
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"body-weight";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerHeartRate : OMHSerializer; @end;
@implementation OMHSerializerHeartRate
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  HKUnit* unit = [HKUnit unitFromString:@"count/min"];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"heart_rate": @{
      @"value": [NSNumber numberWithDouble:value],
      @"unit": @"beats/min"
    },
    @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"heart-rate";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerBloodGlucose : OMHSerializer; @end;
@implementation OMHSerializerBloodGlucose
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  NSString* unitString = @"mg/dL";
  HKUnit* unit = [HKUnit unitFromString:unitString];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"blood_glucose": @{
      @"value": [NSNumber numberWithDouble:value],
      @"unit": unitString
    },
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"blood-glucose";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerEnergyBurned : OMHSerializer; @end;
@implementation OMHSerializerEnergyBurned
+ (BOOL)canSerialize:(HKQuantitySample*)sample error:(NSError**)error {
  return YES;
}
- (id)bodyData {
  NSString* unitString = @"kcal";
  HKUnit* unit = [HKUnit unitFromString:unitString];
  double value =
    [[(HKQuantitySample*)self.sample quantity] doubleValueForUnit:unit];
  return @{
    @"kcal_burned": @{
      @"value": [NSNumber numberWithDouble:value],
      @"unit": unitString
    },
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]

  };
}
- (NSString*)schemaName {
  return @"calories-burned";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerSleepAnalysis : OMHSerializer; @end;
@implementation OMHSerializerSleepAnalysis
+ (BOOL)canSerialize:(HKCategorySample*)sample error:(NSError**)error {
  if (sample.value == HKCategoryValueSleepAnalysisAsleep) return YES;
  if (error) {
    NSString* errorMessage =
      @"Unsupported HKCategoryValueSleepAnalysis value: HKCategoryValueSleepAnalysisInBed";
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : errorMessage };
    *error = [NSError errorWithDomain: OMHErrorDomain
                                 code: OMHErrorCodeUnsupportedValues
                             userInfo: userInfo];
  }
  return NO;
}
- (id)bodyData {
  id value =
    [NSNumber numberWithFloat:
      [self.sample.endDate timeIntervalSinceDate:self.sample.startDate]];
  return @{
    @"sleep_duration": @{
      @"value": value,
      @"unit": @"sec"
    },
    @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"sleep-duration";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerBloodPressure : OMHSerializer; @end;
@implementation OMHSerializerBloodPressure
+ (BOOL)canSerialize:(HKCorrelation*)sample error:(NSError**)error {
  NSSet* samples = sample.objects;
  HKSample* (^firstSampleOfType)(NSString* typeIdentifier) =
    ^HKSample*(NSString* typeIdentifier){
      return [[samples select:^BOOL(HKSample* sample) {
        return [[sample sampleType].identifier isEqual:typeIdentifier];
      }] firstObject];
    };
  HKSample* systolicSample =
    firstSampleOfType(HKQuantityTypeIdentifierBloodPressureSystolic);
  HKSample* diastolicSample =
    firstSampleOfType(HKQuantityTypeIdentifierBloodPressureDiastolic);
  if (systolicSample && diastolicSample) return YES;
  if (error) {
    NSString* errorMessage = @"Missing Diastolic or Systolic sample";
    NSDictionary* userInfo = @{ NSLocalizedDescriptionKey : errorMessage };
    *error = [NSError errorWithDomain: OMHErrorDomain
                                 code: OMHErrorCodeUnsupportedValues
                             userInfo: userInfo];
  }
  return NO;
}
- (id)bodyData {
  NSString* unitString = @"mmHg";
  HKUnit* unit = [HKUnit unitFromString:unitString];
  HKCorrelation* sample = (HKCorrelation*)self.sample;
  double (^valueForFirstSampleOfType)(NSString* typeIdentifier) =
    ^(NSString* typeIdentifier) {
      HKQuantitySample* found =
        [[sample.objects select:^BOOL(HKSample* sample) {
          return [[sample sampleType].identifier isEqual:typeIdentifier];
        }] firstObject];
      return [found.quantity doubleValueForUnit:unit];
    };
  double systolicValue =
    valueForFirstSampleOfType(HKQuantityTypeIdentifierBloodPressureSystolic);
  double diastolicValue =
    valueForFirstSampleOfType(HKQuantityTypeIdentifierBloodPressureDiastolic);
  return @{
    @"systolic_blood_pressure": @{
      @"unit": unitString,
      @"value": [NSNumber numberWithDouble: systolicValue]
    },
    @"diastolic_blood_pressure": @{
      @"unit": unitString,
      @"value": [NSNumber numberWithDouble: diastolicValue]
    },
    @"effective_time_frame": [OMHSerializer populateTimeFrameProperty:self.sample.startDate endDate:self.sample.endDate]
  };
}
- (NSString*)schemaName {
  return @"blood-pressure";
}
- (NSString*)schemaVersion {
  return @"1.0";
}
@end

@interface OMHSerializerBodyMassIndex : OMHSerializer; @end;
@implementation OMHSerializerBodyMassIndex

+ (BOOL)canSerialize:(HKSample *)sample error:(NSError *__autoreleasing *)error {
    if ([sample.sampleType.description isEqualToString:HKQuantityTypeIdentifierBodyMassIndex]){
        return YES;
    }
    return NO;
}
- (id)bodyData {
    NSString *unitStringForValue = @"count";
    HKUnit *unit = [HKUnit unitFromString:unitStringForValue];
    HKQuantitySample *quantitySample = (HKQuantitySample*)self.sample;
    double value = [[quantitySample quantity] doubleValueForUnit:unit];
    NSString *unitStringForSchema = @"kg/m2";
    
    return @{
        @"body_mass_index": @{
            @"value":[NSNumber numberWithDouble:value],
            @"unit":unitStringForSchema
        },
        @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:quantitySample.startDate endDate:quantitySample.endDate]
    };
    
}
- (NSString*)schemaName {
    return @"body-mass-index";
}
- (NSString*)schemaVersion {
    return @"1.0";
}

@end

@interface OMHSerializerGenericQuantitySample : OMHSerializer; @end;
@implementation OMHSerializerGenericQuantitySample

//TODO: Check if there are any necessary details to implement here
+ (BOOL)canSerialize:(HKSample *)sample error:(NSError *__autoreleasing *)error {
    return YES;
}
- (id)bodyData {
    HKQuantitySample *quantitySample = (HKQuantitySample*)self.sample;
    NSArray *metadataArray;
    
    HKQuantity *quantity = [quantitySample quantity];
    NSMutableDictionary *serializedUnitValues = [NSMutableDictionary new];
    if ([quantity isCompatibleWithUnit:[HKUnit unitFromString:@"count"]]) {
        [serializedUnitValues addEntriesFromDictionary:@{
                         @"count": [NSNumber numberWithDouble:[quantity doubleValueForUnit:[HKUnit unitFromString:@"count"]]]
                         }
         ];
    }
    else{
        NSString *unitString = [OMHSerializer parseUnitFromQuantity:quantity];
        [serializedUnitValues addEntriesFromDictionary:@{
                                @"unit_value":@{
                                    @"value": [NSNumber numberWithDouble:[quantity doubleValueForUnit:[HKUnit unitFromString:unitString]]],
                                    @"unit": unitString
                                
                                }
                            }
         ];
    }
      
    NSDictionary *partialSerializedDictionary =
    @{
        @"quantity_type":[[quantitySample quantityType] description] ,
        @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:quantitySample.startDate endDate:quantitySample.endDate]
    } ;
    NSMutableDictionary *fullSerializedDictionary = [partialSerializedDictionary mutableCopy];
    [fullSerializedDictionary addEntriesFromDictionary:serializedUnitValues];
    if (self.sample.metadata.count>0) {
        metadataArray = [OMHSerializer serializeMetadataArray:self.sample.metadata];
        [fullSerializedDictionary setObject:[OMHSerializer serializeMetadataArray:self.sample.metadata] forKey:@"metadata"];
    }
    return fullSerializedDictionary;
}
- (NSString*)schemaName {
    return @"hk-quantity-sample";
}
- (NSString*)schemaVersion {
    return @"1.0";
}
@end

@interface OMHSerializerGenericCategorySample : OMHSerializer; @end;
@implementation OMHSerializerGenericCategorySample

//TODO: Check to see if there are any necessary details to implement here, probably check for sleep and value settings otherwise it will explode
+ (BOOL)canSerialize:(HKSample *)sample error:(NSError *__autoreleasing *)error {
    //check whether the category type is contained in the list of currently appropriate
    return YES;
}
- (id)bodyData {
    HKCategorySample *categorySample = (HKCategorySample*) self.sample;
    NSString *schemaMappedValue = [NSString new];
    if ([[categorySample.categoryType description] isEqualToString:HKCategoryTypeIdentifierSleepAnalysis]){
        switch (categorySample.value){
            case 0:
                schemaMappedValue = @"InBed";
                break;
            case 1:
                schemaMappedValue = @"Asleep";
                break;
        }
    }
    else{
        NSException *e = [NSException
                          exceptionWithName:@"SerializerCategoryTypeIncorrect"
                          reason:@"Generic category sample serializer received incorrect category type"
                          userInfo:nil];
        @throw e;
    }
    
    NSMutableDictionary *fullSerializedDictionary = [NSMutableDictionary new];
    [fullSerializedDictionary addEntriesFromDictionary:@{
                                                    @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:categorySample.startDate endDate:categorySample.endDate],
                                                    @"category_type": [[categorySample categoryType] description],
                                                    @"category_value": schemaMappedValue
                                                    }];
    
    if(self.sample.metadata.count>0){
        [fullSerializedDictionary setObject:[OMHSerializer serializeMetadataArray:self.sample.metadata] forKey:@"metadata"];
    }
    
    return fullSerializedDictionary;
}
- (NSString*)schemaName {
    return @"hk-category-sample";
}
- (NSString*)schemaVersion {
    return @"1.0";
}
@end

@interface OMHSerializerGenericCorrelation : OMHSerializer; @end;
@implementation OMHSerializerGenericCorrelation

//TODO: Implement
+ (BOOL)canSerialize:(HKSample *)sample error:(NSError *__autoreleasing *)error {
    return YES;
}
- (id)bodyData {
    HKCorrelation *correlationSample = (HKCorrelation*)self.sample;
    
    NSMutableArray *quantitySampleArray = [NSMutableArray new];
    NSMutableArray *categorySampleArray = [NSMutableArray new];
    for (NSObject *sample in correlationSample.objects) {
        if ([sample isKindOfClass:[HKQuantitySample class]]){
            //create serialized with the sample input, then call body
            OMHSerializerGenericQuantitySample *quantitySampleSerializer = [OMHSerializerGenericQuantitySample new];
            quantitySampleSerializer = [quantitySampleSerializer initWithSample:(HKQuantitySample*)sample];
            NSDictionary *serializedQuantitySample = (NSDictionary*)[quantitySampleSerializer bodyData];
            [quantitySampleArray addObject:serializedQuantitySample];
        }
        else if ([sample isKindOfClass:[HKCategorySample class]]){
            OMHSerializerGenericCategorySample *categorySampleSerializer = [OMHSerializerGenericCategorySample new];
            categorySampleSerializer = [categorySampleSerializer initWithSample:(HKCategorySample*)sample];
            NSDictionary *serializedCategorySample = (NSDictionary*)[categorySampleSerializer bodyData];
            [quantitySampleArray addObject:serializedCategorySample];
        }
        else {
            NSException *e = [NSException
                              exceptionWithName:@"CorrelationContainsInvalidSample"
                              reason:@"HKCorrelation can only contain samples of type HKQuantitySample or HKCategorySample"
                              userInfo:nil];
            @throw e;
        }
    }
    
    NSMutableDictionary *fullSerializedDictionary = [NSMutableDictionary new];
    [fullSerializedDictionary addEntriesFromDictionary:@{@"effective_time_frame":[OMHSerializer populateTimeFrameProperty:correlationSample.startDate endDate:correlationSample.endDate],
                                                         @"correlation_type":[correlationSample.correlationType description],
                                                         @"quantity_samples":quantitySampleArray,
                                                         @"category_samples":categorySampleArray
                                                         }];
    if(self.sample.metadata.count>0){
        [fullSerializedDictionary setObject:[OMHSerializer serializeMetadataArray:self.sample.metadata] forKey:@"metadata"];
    }
    return fullSerializedDictionary;
    
    
    
}
- (NSString*)schemaName {
    return @"hk-correlation";
}
- (NSString*)schemaVersion {
    return @"1.0";
}
@end

@interface OMHSerializerGenericWorkout : OMHSerializer; @end
@implementation OMHSerializerGenericWorkout

+ (BOOL)canSerialize:(HKSample *)sample error:(NSError *__autoreleasing *)error {
    return YES;
}

- (id)bodyData {
    HKWorkout *workoutSample = (HKWorkout*)self.sample;
    
    NSMutableDictionary *fullSerializedDictionary = [NSMutableDictionary new];
    if(workoutSample.totalDistance){
        NSString *unitString = [OMHSerializer parseUnitFromQuantity:workoutSample.totalDistance];
        [fullSerializedDictionary setObject:@{@"value":[NSNumber numberWithDouble:[workoutSample.totalDistance doubleValueForUnit:[HKUnit unitFromString:unitString]]],@"unit":unitString} forKey:@"distance"];
    }
    if(workoutSample.totalEnergyBurned){
        [fullSerializedDictionary setObject:@{@"value":[NSNumber numberWithDouble:[workoutSample.totalEnergyBurned doubleValueForUnit:[HKUnit unitFromString:@"kcal"]]],@"unit":@"kcal"} forKey:@"kcal_burned"];
    }
    if(workoutSample.duration){
        [fullSerializedDictionary setObject:@{@"value":[NSNumber numberWithDouble:workoutSample.duration],@"unit":@"sec"} forKey:@"duration"];
    }
    
    [fullSerializedDictionary addEntriesFromDictionary:@{
                                                          @"effective_time_frame":[OMHSerializer populateTimeFrameProperty:workoutSample.startDate endDate:workoutSample.endDate],
                                                          @"activity_name":[OMHWorkoutEnumMap stringForHKWorkoutActivityType:workoutSample.workoutActivityType]
                                                          
                                                         }];
    if(self.sample.metadata.count>0){
        [fullSerializedDictionary setObject:[OMHSerializer serializeMetadataArray:self.sample.metadata] forKey:@"metadata"];
    }
    return fullSerializedDictionary;
}

- (NSString*)schemaName {
    return @"hk-workout";
}
- (NSString*)schemaVersion {
    return @"1.0";
}

@end

