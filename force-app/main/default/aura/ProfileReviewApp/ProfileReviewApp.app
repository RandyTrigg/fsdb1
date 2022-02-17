<aura:application extends="force:slds">

    <aura:attribute name="profileId" required="true" type="String" />
    <c:ProfileEdit profileId="{!v.profileId}" />

</aura:application>