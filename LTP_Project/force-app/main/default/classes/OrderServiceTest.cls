@isTest
public class OrderServiceTest {

    @testSetup
    static void setup() {
        // 1. Données de base via Factory
        OrderDataFactory.createTransportData();

        // 2. Création Compte Particulier
        Account acc = new Account(
            Name = 'Client Test', 
            Type_de_compte__c = 'Particulier'
        );
        insert acc;

        // 3. Création Produit & Prix
        Product2 prod = new Product2(Name = 'Produit Test', IsActive = true);
        insert prod;
        
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = Test.getStandardPricebookId(),
            Product2Id = prod.Id,
            UnitPrice = 50.0,
            IsActive = true
        );
        insert pbe;

        // 4. Commande Initiale
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId(),
            BillingCountry = 'France'
        );
        insert ord;
    }

    /**
     * Test des méthodes des Selectors (SOQL)
     * Correction : On utilise les méthodes qui existent réellement dans tes classes
     */
    @isTest
    static void testSelectors() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        // Test de OrderSelector
        Order ordDetail = OrderSelector.getOrderForShipping(ord.Id);
        List<Order> ordWithItems = OrderSelector.getOrdersWithItems(new Set<Id>{ord.Id});
        
        // Test de TransporterSelector
        List<Tarif_transporteur__c> tariffs = TransporterSelector.getAvailableTariffs('France', 'Particulier');
        Test.stopTest();

        System.assertNotEquals(null, ordDetail, 'La commande devrait être récupérée');
        System.assertEquals(1, ordWithItems.size(), 'La liste devrait contenir une commande');
        System.assert(tariffs.size() > 0, 'Des tarifs devraient exister pour la France/Particulier');
    }

    /**
     * Test du LWC (OrderService.getShippingOptions)
     */
    @isTest
    static void testGetShippingOptions() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        
        Test.startTest();
        Map<String, Object> options = OrderService.getShippingOptions(ord.Id);
        Test.stopTest();
        
        System.assert(options.containsKey('allOptions'), 'La map devrait contenir toutes les options');
        System.assert(options.containsKey('cheapest'), 'La map devrait contenir l option la moins chère');
    }

    /**
     * Test de Confirmation LWC (Succès)
     */
    @isTest
    static void testConfirmDeliverySuccess() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Tarif_transporteur__c tarif = [SELECT Transporteur__c FROM Tarif_transporteur__c LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        // On ajoute des produits pour permettre l'activation (Règle Salesforce)
        insert new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 50);

        Test.startTest();
        OrderService.confirmDelivery(ord.Id, tarif.Transporteur__c);
        Test.stopTest();

        Order updatedOrd = [SELECT Status, Transporteur__c FROM Order WHERE Id = :ord.Id];
        System.assertEquals('Activated', updatedOrd.Status);
        System.assertEquals(tarif.Transporteur__c, updatedOrd.Transporteur__c);
    }

    /**
     * Test de Scénario d'Exception (Activation sans produits)
     */
    @isTest
    static void testConfirmDeliveryException() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        Tarif_transporteur__c tarif = [SELECT Transporteur__c FROM Tarif_transporteur__c LIMIT 1];

        Test.startTest();
        try {
            // Tentative d'activation sur une commande VIDE (0 produits)
            OrderService.confirmDelivery(ord.Id, tarif.Transporteur__c);
            System.assert(false, 'Une exception aurait dû être levée');
        } catch (AuraHandledException e) {
            System.debug('Exception gérée : ' + e.getMessage());
            System.assert(true);
        }
        Test.stopTest();
    }

    /**
     * Test de la logique Trigger d'ajout de produits (autoSelectBestCarrier)
     */
    @isTest
    static void testAutoSelectOnItemInsert() {
        Order ord = [SELECT Id FROM Order LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        OrderItem newItem = new OrderItem(
            OrderId = ord.Id, 
            PricebookEntryId = pbe.Id, 
            Quantity = 1, 
            UnitPrice = 50
        );

        Test.startTest();
        // Cela va déclencher ton trigger qui appelle OrderService.autoSelectBestCarrier
        insert newItem;
        Test.stopTest();

        Order updatedOrd = [SELECT Transporteur__c FROM Order WHERE Id = :ord.Id];
        System.assertNotEquals(null, updatedOrd.Transporteur__c, 'Le transporteur devrait être sélectionné automatiquement');
    }
}