namespace System.AI;

table 851 "Cortana Intelligence"
{
    Caption = 'Cortana Intelligence';
    ObsoleteState = Removed;
    ObsoleteReason = 'Renamed to Cash Flow Azure AI Buffer';
    ObsoleteTag = '15.0';
    ReplicateData = false;

    fields
    {
        field(1; "Group Id"; Text[100])
        {
            Caption = 'Group Id';
        }
        field(2; "Period No."; Integer)
        {
            Caption = 'Period No.';
        }
        field(3; Amount; Decimal)
        {
            Caption = 'Amount';
        }
        field(4; Delta; Decimal)
        {
            Caption = 'Delta';
        }
        field(5; "Delta %"; Decimal)
        {
            Caption = 'Delta %';
        }
        field(6; "Period Start"; Date)
        {
            Caption = 'Period Start';
        }
        field(7; "Period Type"; Option)
        {
            Caption = 'Period Type';
            OptionCaption = 'Day,Week,Month,Quarter,Year';
            OptionMembers = Day,Week,Month,Quarter,Year;
        }
        field(8; Type; Option)
        {
            Caption = 'Type';
            OptionCaption = 'History,Forecast,Correction';
            OptionMembers = History,Forecast,Correction;
        }
    }

    keys
    {
        key(Key1; "Period Start", "Group Id")
        {
            Clustered = true;
        }
    }

    fieldgroups
    {
    }
}

