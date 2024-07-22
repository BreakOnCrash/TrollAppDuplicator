#import "RootViewController.h"
#import "AppDuplicator.h"
#import "AppList.h"
#import "thirdparty/TDFileManagerViewController.h"
#import "thirdparty/TDUtils.h"

@implementation RootViewController

- (void)loadView {
    [super loadView];

    self.apps = appList();
    self.duplicator = [[AppDuplicator alloc] init];
    self.title = @"TrollAppDuplicator";
    self.navigationController.navigationBar.prefersLargeTitles = YES;
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"folder"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(openDocs:)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:[UIImage systemImageNamed:@"info.circle"]
                                         style:UIBarButtonItemStylePlain
                                        target:self
                                        action:@selector(about:)];

    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(refreshApps:) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
}

- (void)openDocs:(id)sender {
    TDFileManagerViewController *fmVC = [[TDFileManagerViewController alloc] init];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:fmVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)about:(id)sender {
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:@"TrollAppDuplicator"
                                            message:@"by zznQ\n"
                                                    @"Inspired by TrollDecrypt(fiore)\n"
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Dismiss"
                                              style:UIAlertActionStyleCancel
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)refreshApps:(UIRefreshControl *)refreshControl {
    self.apps = appList();
    [self.tableView reloadData];
    [refreshControl endRefreshing];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.apps.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier = @"AppCell";

    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
                                      reuseIdentifier:cellIdentifier];

    NSDictionary *app = self.apps[indexPath.row];
    cell.textLabel.text = app[@"name"];
    cell.detailTextLabel.text =
        [NSString stringWithFormat:@"%@ • %@", app[@"version"], app[@"bundleID"]];
    cell.imageView.image =
        [UIImage _applicationIconImageForBundleIdentifier:app[@"bundleID"]
                                                   format:iconFormat()
                                                    scale:[UIScreen mainScreen].scale];

    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 80.0f;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIAlertController *alert;
    NSDictionary *app = self.apps[indexPath.row];
    alert = [UIAlertController alertControllerWithTitle:@"Duplicate" 
                message:[NSString stringWithFormat:@"Duplicate %@?", app[@"name"]]
                preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancel = [UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil];
    UIAlertAction *duplicate = [UIAlertAction actionWithTitle:@"Yes" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        UIAlertController *loadingAlert = [UIAlertController alertControllerWithTitle:@"Duplicating" 
            message:@"Please wait, this will take a few seconds..." 
            preferredStyle:UIAlertControllerStyleAlert];
        [self presentViewController:loadingAlert animated:YES completion:nil];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSString *ipa = [self.duplicator duplicateAppWithBundleID:app[@"path"] bundleID:app[@"bundleID"] name:app[@"name"]];
            // 切换回主线程更新 UI
            dispatch_async(dispatch_get_main_queue(), ^{
                [loadingAlert dismissViewControllerAnimated:YES completion:^{
                    UIAlertController *completionAlert = [UIAlertController alertControllerWithTitle: @"Duplication Complete!"
                                                            message:[NSString stringWithFormat: @"IPA file saved " @"to:\n%@", ipa]
                                                            preferredStyle: UIAlertControllerStyleAlert];
                    [completionAlert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
                    [self presentViewController: completionAlert animated:YES completion:nil];
                }];
            });
        });
    }];

    [alert addAction:duplicate];
    [alert addAction:cancel];

    [self presentViewController:alert animated:YES completion:nil];
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
