namespace Microsoft.Warehouse.Activity;

enum 5768 "Warehouse Activity Source Document"
{
    Extensible = true;
    AssignmentCompatibility = true;

    value(0; " ") { Caption = ' '; }
    value(1; "Sales Order") { Caption = 'Sales Order'; }
    value(4; "Sales Return Order") { Caption = 'Sales Return Order'; }
    value(5; "Purchase Order") { Caption = 'Purchase Order'; }
    value(8; "Purchase Return Order") { Caption = 'Purchase Return Order'; }
    value(9; "Inbound Transfer") { Caption = 'Inbound Transfer'; }
    value(10; "Outbound Transfer") { Caption = 'Outbound Transfer'; }
    value(11; "Prod. Consumption") { Caption = 'Prod. Consumption'; }
    value(12; "Prod. Output") { Caption = 'Prod. Output'; }
    value(18; "Service Order") { Caption = 'Service Order'; }
    value(20; "Assembly Consumption") { Caption = 'Assembly Consumption'; }
    value(21; "Assembly Order") { Caption = 'Assembly Order'; }
    value(22; "Job Usage") { Caption = 'Job Usage'; }
}