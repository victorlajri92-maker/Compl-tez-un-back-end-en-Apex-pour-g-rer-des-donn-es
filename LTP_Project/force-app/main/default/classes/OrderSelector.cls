public with sharing class OrderSelector {

    /**
     * Récupère les commandes filtrées par type de compte (Pro ou Particulier).
     */
    public static List<Order> getOrdersByAccountType(String accountType) {
        return [
            SELECT Id, OrderNumber, Status, TotalAmount, Account.Name, Account.Type_de_compte__c 
            FROM Order 
            WHERE Account.Type_de_compte__c = :accountType 
            WITH SECURITY_ENFORCED
            LIMIT 100
        ];
    }

    /**
     * Récupère les commandes pour un pays spécifique qui n'ont pas encore de transporteur.
     */
    public static List<Order> getOrdersByShippingCountry(String country) {
        return [
            SELECT Id, OrderNumber, ShippingCountry, Transporteur__c, Account.Type_de_compte__c
            FROM Order 
            WHERE ShippingCountry = :country 
            AND Transporteur__c = null
            WITH SECURITY_ENFORCED
            LIMIT 50
        ];
    }
}