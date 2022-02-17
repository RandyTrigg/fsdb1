<aura:application extends="force:slds">

    <aura:attribute name="fundId" required="true" type="String" />
    <c:FundReleasing fundId="{!v.fundId}" />

</aura:application>