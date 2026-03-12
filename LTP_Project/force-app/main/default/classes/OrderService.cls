public with sharing class OrderService {

    /**
     * VALIDATION : Vérifie le nombre de produits (3 ou 5).
     */
    public static void validateOrderProducts(List<Order> orders) {
        Set<Id> orderIds = new Set<Id>();
        for (Order o : orders) if (o.Id != null) orderIds.add(o.Id);

        if (orderIds.isEmpty()) return;

        Map<Id, Integer> counts = new Map<Id, Integer>();
        for (AggregateResult ar : [SELECT OrderId, COUNT(Id) total FROM OrderItem WHERE OrderId IN :orderIds GROUP BY OrderId]) {
            counts.put((Id)ar.get('OrderId'), (Integer)ar.get('total'));
        }

        for (Order o : orders) {
            Integer totalProducts = counts.containsKey(o.Id) ? counts.get(o.Id) : 0;
            if (totalProducts != 3 && totalProducts != 5) {
                o.addError('La commande doit contenir exactement 3 ou 5 produits (Actuel : ' + totalProducts + ').');
            }
        }
    }

    /**
     * VALIDATION : Vérifie la compatibilité Client/Transporteur.
     */
    public static void validateCarrierType(List<Order> orders) {
        Set<Id> accountIds = new Set<Id>();
        Set<Id> transporterIds = new Set<Id>();
        for (Order o : orders) {
            if (o.AccountId != null) accountIds.add(o.AccountId);
            if (o.Transporteur__c != null) transporterIds.add(o.Transporteur__c);
        }
        if (accountIds.isEmpty() || transporterIds.isEmpty()) return;

        Map<Id, Account> accountMap = AccountSelector.getAccountsById(accountIds);
        Map<Id, Transporteur__c> transporterMap = TransporterSelector.getTransportersMapById(transporterIds);

        for (Order o : orders) {
            Account acc = accountMap.get(o.AccountId);
            Transporteur__c trans = transporterMap.get(o.Transporteur__c);
            if (acc != null && trans != null && !trans.Type_de_client__c.contains(acc.Type_de_compte__c)) {
                o.addError('Le transporteur ' + trans.Name + ' est incompatible avec un client ' + acc.Type_de_compte__c);
            }
        }
    }

    /**
     * DML & LOGIQUE : Automatise la sélection du meilleur transporteur.
     */
    public static void autoSelectBestCarrier(List<OrderItem> items) {
        Set<Id> orderIds = new Set<Id>();
        for (OrderItem item : items) orderIds.add(item.OrderId);
        
        List<Order> ordersToProcess = [SELECT Id, ShippingCountry, Account.Type_de_compte__c, Transporteur__c FROM Order WHERE Id IN :orderIds];
        List<Order> ordersToUpdate = new List<Order>();

        for (Order ord : ordersToProcess) {
            if (ord.Transporteur__c == null && ord.ShippingCountry != null) {
                List<Transporteur__c> bestCarriers = TransporterSelector.getBestCarriersWithDetails(ord.ShippingCountry, ord.Account.Type_de_compte__c);
                if (!bestCarriers.isEmpty()) {
                    ord.Transporteur__c = bestCarriers[0].Id;
                    ordersToUpdate.add(ord);
                }
            }
        }

        if (!ordersToUpdate.isEmpty()) {
            try {
                update ordersToUpdate;
            } catch (DmlException e) {
                System.debug('Erreur DML Sélection Auto : ' + e.getMessage());
            }
        }
    }

    /**
     * DML : Nettoyage/Suppression des données de livraison.
     */
    public static void clearDeliveryData(Set<Id> orderIds) {
        List<Order> orders = [SELECT Id, Transporteur__c FROM Order WHERE Id IN :orderIds];
        for (Order o : orders) o.Transporteur__c = null;
        try {
            update orders;
        } catch (DmlException e) {
            System.debug('Erreur DML Clear : ' + e.getMessage());
        }
    }
}