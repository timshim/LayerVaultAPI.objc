//
//  LVCAppDelegate.m
//  LayerVaultAPIClient
//
//  Created by Matt Thomas on 10/13/13.
//  Copyright (c) 2013 LayerVault. All rights reserved.
//

#import "LVCAppDelegate.h"
#import "LVCProjectWindowController.h"
#import <LayerVaultAPI/LayerVaultAPI.h>
#import <ReactiveCocoa/ReactiveCocoa.h>
#import <Mantle/EXTScope.h>
#import <Mantle/Mantle.h>
#import "LVCMainWindowController.h"


@interface LVCAppDelegate () <NSTableViewDataSource, NSTableViewDelegate>
@property (weak) IBOutlet NSTableView *projectsTableView;
@property (nonatomic, copy) NSArray *dataSource;

@property (nonatomic) LVCHTTPClient *client;
@property (nonatomic) AFOAuthCredential *credential;
@property (nonatomic) LVCUser *user;

@property (nonatomic) LVCProjectWindowController *projectWindowController;
@property (nonatomic) LVCMainWindowController *mainWindowController;
@end

@implementation LVCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    self.mainWindowController = [[LVCMainWindowController alloc] initWithWindowNibName:@"LVCMainWindowController"];
    [self.mainWindowController showWindow:nil];
    [self.mainWindowController.window makeKeyAndOrderFront:self];
}

- (IBAction)addProjectPressed:(NSButton *)sender
{
    NSInteger row = [self.projectsTableView rowForView:sender];
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCOrganization.class]) {
        LVCOrganization *org = (LVCOrganization *)selectedObject;
        LVCProject *project = [[LVCProject alloc] initWithName:@""
                                         organizationPermalink:org.permalink];
        [self insertDataSourceObject:project
                               inRow:([self.dataSource indexOfObject:org] + 1)];
    }
}


- (IBAction)deleteProjectPressed:(NSButton *)sender
{
    NSInteger row = [self.projectsTableView rowForView:sender];
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCProject.class]) {
        LVCProject *project = (LVCProject *)selectedObject;
        [self.client deleteProject:project
                        completion:^(BOOL success,
                                     NSError *error,
                                     AFHTTPRequestOperation *operation) {
                            if (success) {
                                [self deleteDataSourceObjectInRow:row];
                            }
                        }];
    }
}

- (IBAction)changeColorPressed:(NSButton *)sender
{
    NSInteger row = [self.projectsTableView rowForView:sender];
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCProject.class]) {
        LVCProject *project = (LVCProject *)selectedObject;
        LVCColorLabel newLabel = LVCColorWhite;
        switch (project.colorLabel) {
            case LVCColorWhite:
                newLabel = LVCColorGreen;
                break;
            case LVCColorGreen:
                newLabel = LVCColorRed;
                break;
            case LVCColorRed:
                newLabel = LVCColorOrange;
                break;
            case LVCColorOrange:
                newLabel = LVCColorWhite;
                break;
        }

        [self.client updateProject:project
                        colorLabel:newLabel
                        completion:^(BOOL success,
                                     NSError *error,
                                     AFHTTPRequestOperation *operation) {
                            if (success) {
                                [self.projectsTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                                                  columnIndexes:[NSIndexSet indexSetWithIndex:0]];
                            }
                        }];
    }
}


- (IBAction)textFieldTitleChanged:(NSTextField *)textField
{
    NSInteger row = [self.projectsTableView rowForView:textField];
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCProject.class]) {
        LVCProject *project = (LVCProject *)selectedObject;

        void (^completion)(LVCProject *, NSError *, AFHTTPRequestOperation *) =
        ^(LVCProject *project,
          NSError *error,
          AFHTTPRequestOperation *operation) {
            if (project) {
                [self updateDataSourceObject:project
                                       inRow:row];
            }
            else {
                NSLog(@"error: %@", error);
            }
        };

        if (!project.synced) {
            [self.client createProjectWithName:textField.stringValue
                         organizationPermalink:project.organizationPermalink
                                    completion:completion];
        }
        else {
            if (![textField.stringValue isEqualToString:project.name]) {
                [self.client renameProject:(LVCProject *)project
                                   newName:textField.stringValue
                                completion:completion];
            }
        }
    }
}


- (void)setDataSourceForUser:(LVCUser *)user
{
    for (LVCOrganization *org in user.organizations) {
        for (LVCProject *currentProject in org.projects) {
            if (currentProject.member) {
                if (currentProject.partial) {
                    [self.client getProjectFromPartial:currentProject
                                            completion:^(LVCProject *project,
                                                         NSError *error,
                                                         AFHTTPRequestOperation *operation) {
                                                [currentProject mergeValuesForKeysFromModel:project];
                                                [self updateDataSource];
                    }];
                }
            }
        }
    }
    [self updateDataSource];
}


- (void)updateDataSource
{
    NSMutableArray *dataSource = @[].mutableCopy;
    for (LVCOrganization *org in self.user.organizations) {
        [dataSource addObject:org];
        NSArray *sortedProjects = [org.projects sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"dateUpdated" ascending:NO]]];
        for (LVCProject *currentProject in sortedProjects) {
            if (currentProject.member) {
                if (!currentProject.partial) {
                    [dataSource addObject:currentProject];
                }
            }
        }
    }
    self.dataSource = dataSource;
    [self.projectsTableView reloadData];
}


- (void)insertDataSourceObject:(id)object inRow:(NSUInteger)row
{
    NSMutableArray *newDataSource = self.dataSource.mutableCopy;
    [newDataSource insertObject:object atIndex:row];
    self.dataSource = newDataSource;
    [self.projectsTableView insertRowsAtIndexes:[NSIndexSet indexSetWithIndex:row]
                                  withAnimation:NSTableViewAnimationEffectNone];
}


- (void)deleteDataSourceObjectInRow:(NSUInteger)row
{
    NSMutableArray *newDataSource = self.dataSource.mutableCopy;
    [newDataSource removeObjectAtIndex:row];
    self.dataSource = newDataSource;
    [self.projectsTableView removeRowsAtIndexes:[NSIndexSet indexSetWithIndex:row]
                                  withAnimation:NSTableViewAnimationSlideUp];
}


- (void)updateDataSourceObject:(id)object inRow:(NSUInteger)row
{
    NSMutableArray *newDataSource = self.dataSource.mutableCopy;
    [newDataSource replaceObjectAtIndex:row withObject:object];
    self.dataSource = newDataSource;
    [self.projectsTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:row]
                                      columnIndexes:[NSIndexSet indexSetWithIndex:0]];

}


#pragma mark - NSTableViewDataSource
- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
    return self.dataSource.count;
}


#pragma mark - NSTableViewDelegate
- (void)tableView:(NSTableView *)tableView didAddRowView:(NSTableRowView *)rowView forRow:(NSInteger)row
{
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCProject.class]) {
        LVCProject *project = (LVCProject *)selectedObject;
        if (!project.synced) {
            [tableView editColumn:0 row:row withEvent:nil select:YES];
        }
    }
}


- (NSView *)tableView:(NSTableView *)tableView
   viewForTableColumn:(NSTableColumn *)tableColumn
                  row:(NSInteger)row
{
    id selectedObject = [self.dataSource objectAtIndex:row];

    if ([selectedObject isKindOfClass:LVCOrganization.class]) {
        LVCOrganization *org = (LVCOrganization *)selectedObject;
        NSTableCellView *orgCell = [tableView makeViewWithIdentifier:@"OrganizationCell"
                                                               owner:self];
        [orgCell.textField setStringValue:org.name];
        return orgCell;
    }
    else if ([selectedObject isKindOfClass:LVCProject.class]) {
        LVCProject *project = (LVCProject *)selectedObject;
        NSTableCellView *tableCell = [tableView makeViewWithIdentifier:@"ProjectCell"
                                                                 owner:self];
        if (project.synced) {
            [tableCell.textField setStringValue:project.name];
            NSButton *button = [tableCell viewWithTag:32];
            [button.cell setBackgroundColor:[LVCColorUtils colorForLabel:project.colorLabel]];
        }
        return tableCell;
    }
    return nil;
}


- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)row
{
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCOrganization.class]) {
        return YES;
    }
    return NO;
}


- (void)doubleClickedTable:(NSTableView *)tableView
{
    NSInteger row = tableView.selectedRow;
    id selectedObject = [self.dataSource objectAtIndex:row];
    if ([selectedObject isKindOfClass:LVCProject.class]) {

        if (!self.projectWindowController) {
            self.projectWindowController = [[LVCProjectWindowController alloc] initWithClient:self.client];
        }

        [self.projectWindowController showWindow:nil];

        LVCProject *project = (LVCProject *)selectedObject;
        if (project.partial) {
            @weakify(self);
            [self.client getProjectFromPartial:project
                                    completion:^(LVCProject *project,
                                                 NSError *error,
                                                 AFHTTPRequestOperation *operation) {
                                        @strongify(self);
                                        self.projectWindowController.project = project;
                                    }];
        }
        else {
            self.projectWindowController.project = project;
        }
    }
}

@end
