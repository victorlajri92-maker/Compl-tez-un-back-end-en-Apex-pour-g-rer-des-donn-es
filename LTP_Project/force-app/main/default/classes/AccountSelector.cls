public with sharing class AccountSelector {
    
    /**
     * @description Récupère une Map de comptes avec leurs Record Types à partir d'un Set d'IDs.
     */
    public static Map<Id, Account> getAccountsById(Set<Id> accountIds) {
        if (accountIds == null || accountIds.isEmpty()) {
            return new Map<Id, Account>();
        }
        
        return new Map<Id, Account>([
            SELECT Id, Name, RecordType.DeveloperName 
            FROM Account 
            WHERE Id IN :accountIds
        ]);
    }

    /**
     * @description Version pour un seul ID (utile pour le LWC ou des besoins unitaires).
     */
    public static Account getAccountById(Id accountId) {
        if (accountId == null) return null;
        
        List<Account> accounts = [
            SELECT Id, Name, RecordType.DeveloperName 
            FROM Account 
            WHERE Id = :accountId 
            LIMIT 1
        ];
        return accounts.isEmpty() ? null : accounts[0];
    }
}