//
//  MyParentTableViewController.m
//  MyKidCheckin
//
//  Created by Rui Yang on 4/9/15.
//  Copyright (c) 2015 Rui Yang. All rights reserved.
//

#import "MyParentTableViewController.h"
#import "MyKidViewDetailController.h"
#import "MyChildCell.h"

@interface MyParentTableViewController () <MyKidViewDetailControllerDelegate>{
    NSString * parentId;
    NSMutableArray *objects;
}

@end

@implementation MyParentTableViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    parentId = @"parent"; // use a fake parent id for demo change to real one in the future.

}

- (void) saveObjects {
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0]; // Get documents directory
    NSError *error;
    NSMutableArray * result = [[NSMutableArray alloc] init];
    
    for (NSUInteger i = 0; i < [objects count]; i++) {
        id obj = [objects objectAtIndex:i];
        NSData * d = [NSJSONSerialization dataWithJSONObject:obj options:0 error:nil];
        NSString * r = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
        [result addObject:r];
    }
    
    
    BOOL succeed = [[result componentsJoinedByString:@"\n"] writeToFile:[documentsDirectory stringByAppendingPathComponent:@"kids.info"]
        atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (!succeed){
        // Handle error here
    }
}

- (void) onChild:(NSDictionary *)childInfo {
    NSMutableDictionary * dict = [NSMutableDictionary dictionaryWithDictionary:childInfo];
    [objects insertObject:dict atIndex:0];
    [self saveObjects];
    [self.tableView reloadData];
}

- (IBAction)addNewKids:(id)sender {
    NSLog(@"add new kids clicked");
    if (!objects) {
        objects = [[NSMutableArray alloc] init];
    }
    [self showChildEdit:YES childId:nil childName:nil];
}

- (void) showChildEdit:(BOOL) allowEdit childId:(NSString *) childId childName:(NSString*) childName {
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    MyKidViewDetailController *vc = (MyKidViewDetailController*)[storyboard instantiateViewControllerWithIdentifier:@"kidDetailViewController"];
    
    vc.parentId = parentId;
    vc.childId = childId ? childId : [[NSUUID UUID] UUIDString];
    vc.delegate = self;
    vc.allowEdit = allowEdit;
    if (childName) {
        vc.myText.text = childName;
    }
    
    [[self navigationController] pushViewController:vc animated:NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
    return [objects count];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Display Alert Message
}

- (NSString *) safeStr:(NSDictionary *) row key:(NSString *) key {
    NSString * r = @"";
    if ([row objectForKey:key]) {
        return [row objectForKey:key];
    }
    return r;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    MyChildCell *cell = [tableView dequeueReusableCellWithIdentifier:@"MyKidCell" forIndexPath:indexPath];
    NSDictionary * row = [objects objectAtIndex:indexPath.row];
    NSArray * array = @[ [self safeStr:row key:@"name"],  [self safeStr:row key:@"time"],  [self safeStr:row key:@"geo"]];
    cell.myName.text = [array componentsJoinedByString:@"\n"];
//    cell.myTime.text = [row objectForKey:@"time"];
//    cell.myGeo.text = [row objectForKey:@"geo"];
    cell.childId = [row objectForKey:@"id"];
    cell.parentId = parentId;
    // Configure the cell...
    cell.contentView.userInteractionEnabled = NO;
    return cell;
}

- (void) pingChildAtIndex:(NSIndexPath *) indexPath {
    
}

- (NSArray *)tableView:(UITableView *)tableView editActionsForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    UITableViewRowAction *moreAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"Ping" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        // maybe show an action sheet with more options
        [tableView setEditing:NO];
        // send ping here
        [self pingChildAtIndex:indexPath];
    }];
    moreAction.backgroundColor = [UIColor blueColor];
    
    UITableViewRowAction *moreAction2 = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal title:@"QR" handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        [tableView setEditing:NO];
        NSDictionary * row = [objects objectAtIndex:indexPath.row];
        [self showChildEdit:NO childId:[row objectForKey:@"id"] childName:[row objectForKey:@"name"]];
    }];
    moreAction2.backgroundColor = [UIColor blueColor];
    
    UITableViewRowAction *deleteAction = [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleDestructive title:@"Delete"  handler:^(UITableViewRowAction *action, NSIndexPath *indexPath){
        //[self.tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
        [objects removeObjectAtIndex:indexPath.row];
        [tableView reloadData];
    }];
    
    return @[deleteAction, moreAction, moreAction2];
}


// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}



// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}





// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return NO;
}



#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    NSString * identifier = [segue identifier];
    if ([identifier isEqualToString:@"kidDetailViewController"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        id object = [objects objectAtIndex:indexPath.row];
        MyKidViewDetailController * kidVC = (MyKidViewDetailController*) [segue destinationViewController] ;
        kidVC.parentId = parentId;
        kidVC.childId = [object objectForKey:@"childId"];
        //[[segue destinationViewController] setDetailItem:object];
    }
}


@end
