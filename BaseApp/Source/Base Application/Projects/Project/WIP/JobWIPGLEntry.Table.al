namespace Microsoft.Projects.Project.WIP;

using Microsoft.Finance.Dimension;
using Microsoft.Finance.GeneralLedger.Account;
using Microsoft.Finance.GeneralLedger.Ledger;
using Microsoft.Projects.Project.Job;
using Microsoft.Utilities;

table 1005 "Job WIP G/L Entry"
{
    Caption = 'Job WIP G/L Entry';
    DrillDownPageID = "Job WIP G/L Entries";
    LookupPageID = "Job WIP G/L Entries";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
        }
        field(2; "Job No."; Code[20])
        {
            Caption = 'Job No.';
            TableRelation = Job;
        }
        field(3; "Document No."; Code[20])
        {
            Caption = 'Document No.';
        }
        field(4; "G/L Account No."; Code[20])
        {
            Caption = 'G/L Account No.';
            TableRelation = "G/L Account";
        }
        field(5; "Posting Date"; Date)
        {
            Caption = 'Posting Date';
        }
        field(6; "WIP Entry Amount"; Decimal)
        {
            Caption = 'WIP Entry Amount';
        }
        field(7; "Job Posting Group"; Code[20])
        {
            Caption = 'Job Posting Group';
            TableRelation = "Job Posting Group";
        }
        field(8; Type; Enum "Job WIP Buffer Type")
        {
            Caption = 'Type';
        }
        field(9; "G/L Bal. Account No."; Code[20])
        {
            Caption = 'G/L Bal. Account No.';
            TableRelation = "G/L Account";
        }
        field(10; "WIP Method Used"; Code[20])
        {
            Caption = 'WIP Method Used';
            Editable = false;
            TableRelation = "Job WIP Method";
        }
        field(11; "WIP Posting Method Used"; Option)
        {
            Caption = 'WIP Posting Method Used';
            OptionCaption = 'Per Job,Per Job Ledger Entry';
            OptionMembers = "Per Job","Per Job Ledger Entry";
        }
        field(12; "WIP Posting Date"; Date)
        {
            Caption = 'WIP Posting Date';
        }
        field(13; Description; Text[100])
        {
            Caption = 'Description';
        }
        field(14; "G/L Entry No."; Integer)
        {
            BlankZero = true;
            Caption = 'G/L Entry No.';
            TableRelation = "G/L Entry";
        }
        field(15; Reversed; Boolean)
        {
            Caption = 'Reversed';
        }
        field(16; Reverse; Boolean)
        {
            Caption = 'Reverse';
            InitValue = true;
        }
        field(17; "WIP Transaction No."; Integer)
        {
            Caption = 'WIP Transaction No.';
        }
        field(18; "Reverse Date"; Date)
        {
            Caption = 'Reverse Date';
        }
        field(19; "Job Complete"; Boolean)
        {
            Caption = 'Job Complete';
        }
        field(20; "Job WIP Total Entry No."; Integer)
        {
            Caption = 'Job WIP Total Entry No.';
            TableRelation = "Job WIP Total";
        }
        field(60; "Global Dimension 1 Code"; Code[20])
        {
            CaptionClass = '1,1,1';
            Caption = 'Global Dimension 1 Code';
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(1));
        }
        field(61; "Global Dimension 2 Code"; Code[20])
        {
            CaptionClass = '1,1,2';
            Caption = 'Global Dimension 2 Code';
            TableRelation = "Dimension Value".Code where("Global Dimension No." = const(2));
        }
        field(480; "Dimension Set ID"; Integer)
        {
            Caption = 'Dimension Set ID';
            Editable = false;
            TableRelation = "Dimension Set Entry";

            trigger OnLookup()
            begin
                Rec.ShowDimensions();
            end;
        }
        field(481; "Shortcut Dimension 3 Code"; Code[20])
        {
            CaptionClass = '1,2,3';
            Caption = 'Shortcut Dimension 3 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(3)));
        }
        field(482; "Shortcut Dimension 4 Code"; Code[20])
        {
            CaptionClass = '1,2,4';
            Caption = 'Shortcut Dimension 4 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(4)));
        }
        field(483; "Shortcut Dimension 5 Code"; Code[20])
        {
            CaptionClass = '1,2,5';
            Caption = 'Shortcut Dimension 5 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(5)));
        }
        field(484; "Shortcut Dimension 6 Code"; Code[20])
        {
            CaptionClass = '1,2,6';
            Caption = 'Shortcut Dimension 6 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(6)));
        }
        field(485; "Shortcut Dimension 7 Code"; Code[20])
        {
            CaptionClass = '1,2,7';
            Caption = 'Shortcut Dimension 7 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(7)));
        }
        field(486; "Shortcut Dimension 8 Code"; Code[20])
        {
            CaptionClass = '1,2,8';
            Caption = 'Shortcut Dimension 8 Code';
            Editable = false;
            FieldClass = FlowField;
            CalcFormula = lookup("Dimension Set Entry"."Dimension Value Code" where("Dimension Set ID" = field("Dimension Set ID"),
                                                                                    "Global Dimension No." = const(8)));
        }
    }

    keys
    {
        key(Key1; "Entry No.")
        {
            Clustered = true;
        }
        key(Key2; "Job No.", Reversed, "Job Complete", Type)
        {
            SumIndexFields = "WIP Entry Amount";
        }
        key(Key3; "Job No.", Reverse, "Job Complete", Type)
        {
            SumIndexFields = "WIP Entry Amount";
        }
        key(Key4; "Document No.", "Posting Date")
        {
        }
        key(Key5; "WIP Transaction No.")
        {
        }
    }

    fieldgroups
    {
    }

    var
        DimMgt: Codeunit DimensionManagement;

    procedure GetLastEntryNo(): Integer;
    var
        FindRecordManagement: Codeunit "Find Record Management";
    begin
        exit(FindRecordManagement.GetLastEntryIntFieldValue(Rec, FieldNo("Entry No.")))
    end;

    procedure ShowDimensions()
    begin
        DimMgt.ShowDimensionSet("Dimension Set ID", StrSubstNo('%1 %2', TableCaption(), "Entry No."));
    end;
}

