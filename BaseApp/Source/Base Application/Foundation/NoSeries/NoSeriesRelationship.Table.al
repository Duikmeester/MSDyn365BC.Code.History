// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace Microsoft.Foundation.NoSeries;

table 310 "No. Series Relationship"
{
    Caption = 'No. Series Relationship';
    DrillDownPageID = "No. Series Relationships";
    LookupPageID = "No. Series Relationships";

    fields
    {
        field(1; "Code"; Code[20])
        {
            Caption = 'Code';
            NotBlank = true;
            TableRelation = "No. Series";

            trigger OnValidate()
            begin
                CalcFields(Description);
            end;
        }
        field(2; "Series Code"; Code[20])
        {
            Caption = 'Series Code';
            NotBlank = true;
            TableRelation = "No. Series";

            trigger OnValidate()
            begin
                CalcFields("Series Description");
            end;
        }
        field(3; Description; Text[100])
        {
            CalcFormula = Lookup("No. Series".Description where(Code = field(Code)));
            Caption = 'Description';
            Editable = false;
            FieldClass = FlowField;
        }
        field(4; "Series Description"; Text[100])
        {
            CalcFormula = Lookup("No. Series".Description where(Code = field("Series Code")));
            Caption = 'Series Description';
            Editable = false;
            FieldClass = FlowField;
        }
    }

    keys
    {
        key(Key1; "Code", "Series Code")
        {
            Clustered = true;
        }
        key(Key2; "Series Code", "Code")
        {
        }
    }

    fieldgroups
    {
    }
}

