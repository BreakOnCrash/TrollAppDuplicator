#import "AppDuplicator.h"
#import <UIKit/UIKit.h>

@interface RootViewController : UITableViewController

@property(nonatomic, strong) NSArray *apps;
@property(nonatomic, strong) AppDuplicator *duplicator;

@end
