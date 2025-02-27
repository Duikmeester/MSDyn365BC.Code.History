// ------------------------------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// Licensed under the MIT License. See License.txt in the project root for license information.
// ------------------------------------------------------------------------------------------------

namespace System.Apps;

using System;

/// <summary>
/// Installs the selected extension.
/// </summary>
page 2503 "Extension Installation"
{
    Extensible = false;
    PageType = Card;
    SourceTable = "Extension Installation";
    SourceTableTemporary = true;
    ContextSensitiveHelpPage = 'ui-extensions';

    trigger OnFindRecord(Which: Text): Boolean
    begin
        CurrPage.Close();
    end;

    trigger OnOpenPage()
    var
        ExtensionMarketplace: Codeunit "Extension Marketplace";
        MarketplaceExtnDeployment: Page "Marketplace Extn Deployment";
    begin
        GetDetailsFromFilters();

        MarketplaceExtnDeployment.SetAppID(Rec.ID);
        MarketplaceExtnDeployment.SetPreviewKey(Rec.PreviewKey);
        MarketplaceExtnDeployment.RunModal();
        if MarketplaceExtnDeployment.GetInstalledSelected() then
            if not IsNullGuid(Rec.ID) then
                ExtensionMarketplace.InstallMarketplaceExtension(
                    Rec.ID,
                    Rec.ResponseUrl,
                    MarketplaceExtnDeployment.GetLanguageId(),
                    Rec.PreviewKey);
        CurrPage.Close();
    end;

    local procedure GetDetailsFromFilters()
    var
        RecordRef: RecordRef;
        i: Integer;
    begin
        RecordRef.GetTable(Rec);
        for i := 1 to RecordRef.FieldCount() do
            ParseFilter(RecordRef.FieldIndex(i));
        RecordRef.SetTable(Rec);
    end;

    local procedure ParseFilter(FieldRef: FieldRef)
    var
        FilterPrefixDotNet_Regex: DotNet Regex;
        SingleQuoteDotNet_Regex: DotNet Regex;
        EscapedEqualityDotNet_Regex: DotNet Regex;
        "Filter": Text;
    begin
        Filter := FieldRef.GetFilter();
        if (Filter = '') then
            exit;

        FilterPrefixDotNet_Regex := FilterPrefixDotNet_Regex.Regex('^@\*([^\\]+)\*$');
        SingleQuoteDotNet_Regex := SingleQuoteDotNet_Regex.Regex('^''([^\\]+)''$');
        EscapedEqualityDotNet_Regex := EscapedEqualityDotNet_Regex.Regex('~');

        Filter := FilterPrefixDotNet_Regex.Replace(Filter, '$1');
        Filter := SingleQuoteDotNet_Regex.Replace(Filter, '$1');
        Filter := EscapedEqualityDotNet_Regex.Replace(Filter, '=');

        if Filter <> '' then
            FieldRef.Value(Filter);
    end;
}