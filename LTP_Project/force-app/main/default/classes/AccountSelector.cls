public with sharing class AccountSelector {
    public static Map<Id, Account> getAccountsById(Set<Id> accountIds) {
        return new Map<Id, Account>([
            SELECT Id, Type_de_compte__c 
            FROM Account 
            WHERE Id IN :accountIds
        ]);
    }
}