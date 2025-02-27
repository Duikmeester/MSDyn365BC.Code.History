namespace Microsoft.Projects.RoleCenters;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;
using Microsoft.Projects.Project.Setup;
using Microsoft.Projects.Project.WIP;
using System;
using System.Environment;
using System.Visualization;

page 9068 "Project Manager Activities"
{
    Caption = 'Activities';
    PageType = CardPart;
    RefreshOnActivate = true;
    ShowFilter = false;
    SourceTable = "Job Cue";

    layout
    {
        area(content)
        {
            cuegroup(Invoicing)
            {
                Caption = 'Invoicing';
                Visible = SetupIsComplete;
                field("Upcoming Invoices"; Rec."Upcoming Invoices")
                {
                    ApplicationArea = Jobs;
                    DrillDownPageID = "Job List";
                    ToolTip = 'Specifies the number of upcoming invoices that are displayed in the Job Cue on the Role Center. The documents are filtered by today''s date.';
                }
                field("Invoices Due - Not Created"; Rec."Invoices Due - Not Created")
                {
                    ApplicationArea = Jobs;
                    DrillDownPageID = "Job List";
                    ToolTip = 'Specifies the number of invoices that are due but not yet created that are displayed in the Job Cue on the Role Center. The documents are filtered by today''s date.';
                }

                actions
                {
                    action("Job Create Sales Invoice")
                    {
                        ApplicationArea = Jobs;
                        Caption = 'Job Create Sales Invoice';
                        RunObject = Report "Job Create Sales Invoice";
                        ToolTip = 'Create an invoice for a job or for one or more job tasks for a customer when either the work to be invoiced is complete or the date for invoicing based on an invoicing schedule has been reached.';
                    }
                }
            }
            cuegroup("Work in Process")
            {
                Caption = 'Work in Process';
                Visible = SetupIsComplete;
                field("WIP Not Posted"; Rec."WIP Not Posted")
                {
                    ApplicationArea = Suite;
                    DrillDownPageID = "Job List";
                    ToolTip = 'Specifies the amount of work in process that has not been posted that is displayed in the Service Cue on the Role Center. The documents are filtered by today''s date.';
                }
                field("Completed - WIP Not Calculated"; Rec."Completed - WIP Not Calculated")
                {
                    ApplicationArea = Suite;
                    DrillDownPageID = "Job List";
                    ToolTip = 'Specifies the total of work in process that is complete but not calculated that is displayed in the Job Cue on the Role Center. The documents are filtered by today''s date.';
                }

                actions
                {
                    action("Update Job Item Cost")
                    {
                        ApplicationArea = Jobs;
                        Caption = 'Update Job Item Cost';
                        RunObject = Report "Update Job Item Cost";
                        ToolTip = 'Update the usage costs in the job ledger entries to match the actual costs in the item ledger entry. If adjustment value entries have a different date than the original value entry, such as when the inventory period is closed, then the job ledger is not updated.';
                    }
                    action("<Action15>")
                    {
                        ApplicationArea = Jobs;
                        Caption = 'Job WIP Cockpit';
                        RunObject = Page "Job WIP Cockpit";
                        ToolTip = 'Get an overview of work in process (WIP). The Job WIP Cockpit is the central location to track WIP for all of your projects. Each line contains information about a job, including calculated and posted WIP.';
                    }
                }
            }
            cuegroup("Jobs to Budget")
            {
                Caption = 'Jobs to Budget';
                Visible = SetupIsComplete;
                field("Jobs Over Budget"; Rec."Jobs Over Budget")
                {
                    ApplicationArea = Jobs;
                    Caption = 'Over Budget';
                    DrillDownPageID = "Job List";
                    Editable = false;
                    ToolTip = 'Specifies the number of jobs where the usage cost exceeds the budgeted cost.';
                }
            }
            cuegroup("Get started")
            {
                Caption = 'Get started';
                Visible = ReplayGettingStartedVisible;

                actions
                {
                    action(ShowStartInMyCompany)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Try with my own data';
                        Image = TileSettings;
                        ToolTip = 'Set up My Company with the settings you choose. We''ll show you how, it''s easy.';
                        Visible = false;

                        trigger OnAction()
                        begin
                            if UserTours.IsAvailable() and O365GettingStartedMgt.AreUserToursEnabled() then
                                UserTours.StartUserTour(O365GettingStartedMgt.GetChangeCompanyTourID());
                        end;
                    }
                    action(ReplayGettingStarted)
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Replay Getting Started';
                        Image = TileVideo;
                        ToolTip = 'Show the Getting Started guide again.';

                        trigger OnAction()
                        var
                            O365GettingStarted: Record "O365 Getting Started";
                        begin
                            if O365GettingStarted.Get(UserId, ClientTypeManagement.GetCurrentClientType()) then begin
                                O365GettingStarted."Tour in Progress" := false;
                                O365GettingStarted."Current Page" := 1;
                                O365GettingStarted.Modify();
                                Commit();
                            end;

                            O365GettingStartedMgt.LaunchWizard(true, false);
                        end;
                    }
                }
            }
            cuegroup(Jobs)
            {
                Caption = 'Jobs';
                Visible = NOT SetupIsComplete;

                actions
                {
                    action("<PageJobSetup>")
                    {
                        ApplicationArea = Basic, Suite;
                        Caption = 'Set Up Jobs';
                        Image = TileSettings;
                        RunObject = Page "Jobs Setup Wizard";
                        RunPageMode = Create;
                        ToolTip = 'Open the assisted setup guide to set up how you want to use jobs.';
                    }
                }
            }
        }
    }

    actions
    {
        area(processing)
        {
            action("Set Up Cues")
            {
                ApplicationArea = Basic, Suite;
                Caption = 'Set Up Cues';
                Image = Setup;
                ToolTip = 'Set up the cues (status tiles) related to the role.';

                trigger OnAction()
                var
                    CueRecordRef: RecordRef;
                begin
                    CueRecordRef.GetTable(Rec);
                    CuesAndKpis.OpenCustomizePageForCurrentUser(CueRecordRef.Number);
                end;
            }
        }
    }

    trigger OnAfterGetCurrRecord()
    begin
        O365GettingStartedMgt.UpdateGettingStartedVisible(TileGettingStartedVisible, ReplayGettingStartedVisible);
    end;

    trigger OnInit()
    var
        JobsSetup: Record "Jobs Setup";
        MyCompName: Text;
    begin
        O365GettingStartedMgt.UpdateGettingStartedVisible(TileGettingStartedVisible, ReplayGettingStartedVisible);

        SetupIsComplete := false;

        MyCompName := CompanyName;

        if JobsSetup.FindFirst() then
            if MyCompName = MyCompanyTxt then
                SetupIsComplete := JobsSetup."Default Job Posting Group" <> ''
            else
                SetupIsComplete := JobsSetup."Job Nos." <> '';

        OnAfterInit(SetupIsComplete);
    end;

    trigger OnOpenPage()
    begin
        Rec.Reset();
        if not Rec.Get() then begin
            Rec.Init();
            Rec.Insert();
        end;

        Rec.SetFilter("Date Filter", '>=%1', WorkDate());
        Rec.SetFilter("Date Filter2", '<%1&<>%2', WorkDate(), 0D);
        Rec.SetRange("User ID Filter", UserId());

        ShowIntelligentCloud := not EnvironmentInfo.IsSaaS();
    end;

    var
        CuesAndKpis: Codeunit "Cues And KPIs";
        O365GettingStartedMgt: Codeunit "O365 Getting Started Mgt.";
        ClientTypeManagement: Codeunit "Client Type Management";
        EnvironmentInfo: Codeunit "Environment Information";
        [RunOnClient]
        [WithEvents]
        UserTours: DotNet UserTours;
        ReplayGettingStartedVisible: Boolean;
        TileGettingStartedVisible: Boolean;
        SetupIsComplete: Boolean;
        MyCompanyTxt: Label 'My Company';
        ShowIntelligentCloud: Boolean;

    procedure RefreshRoleCenter()
    begin
        CurrPage.Update();
    end;

    [IntegrationEvent(true, false)]
    local procedure OnAfterInit(var SetupIsComplete: Boolean)
    begin
    end;

    trigger UserTours::ShowTourWizard(hasTourCompleted: Boolean)
    begin
    end;

    trigger UserTours::IsTourInProgressResultReady(isInProgress: Boolean)
    begin
    end;
}

