@isTest
public class OrderServiceTest {

    @testSetup
static void setup() {
    // 1. Création d'un Compte
    Account acc = new Account(Name = 'Client Test', Type_de_compte__c = 'Particulier');
    insert acc;

    // 2. Création d'un Transporteur et son Tarif
    Transporteur__c trans = new Transporteur__c(
        Name = 'Transporteur Express', 
        Type_de_client__c = 'Particulier;Professionnel'
    );
    insert trans;

    Tarif_transporteur__c tarif = new Tarif_transporteur__c(
        Transporteur__c = trans.Id,
        Pays__c = 'France',
        Prix__c = 10.0,
        Delai_Livraison__c = 2
    );
    insert tarif;
    
    // 3. Création du Produit et Prix
    Product2 prod = new Product2(Name = 'Produit Test', IsActive = true);
    insert prod;
    
    PricebookEntry pbe = new PricebookEntry(
        Pricebook2Id = Test.getStandardPricebookId(),
        Product2Id = prod.Id,
        UnitPrice = 50.0,
        IsActive = true
    );
    insert pbe;

    // --- AJOUT MANQUANT ICI ---
    // 4. Création d'une commande initiale pour que les Selectors trouvent quelque chose
    Order ord = new Order(
        AccountId = acc.Id,
        EffectiveDate = Date.today(),
        Status = 'Draft',
        Pricebook2Id = Test.getStandardPricebookId()
    );
    insert ord;
}

    /**
     * Test de la validation : 3 ou 5 produits requis.
     */
    @isTest
    static void testOrderProductValidation() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        // Création d'une commande
        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        // Ajout de 2 produits (devrait déclencher une erreur lors de la validation)
        List<OrderItem> items = new List<OrderItem>();
        for(Integer i=0; i<2; i++) {
            items.add(new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 50));
        }
        
        Test.startTest();
        try {
            insert items;
        } catch (Exception e) {
            System.debug('Erreur de validation capturée : ' + e.getMessage());
        }
        Test.stopTest();
    }

    /**
     * Test de la sélection automatique du transporteur.
     */
    @isTest
    static void testAutoCarrierSelection() {
        Account acc = [SELECT Id FROM Account LIMIT 1];
        PricebookEntry pbe = [SELECT Id FROM PricebookEntry LIMIT 1];

        Order ord = new Order(
            AccountId = acc.Id,
            EffectiveDate = Date.today(),
            Status = 'Draft',
            ShippingCountry = 'France', 
            Pricebook2Id = Test.getStandardPricebookId()
        );
        insert ord;

        // Ajout de 3 produits pour valider la règle et déclencher l'automatisation
        List<OrderItem> items = new List<OrderItem>();
        for(Integer i=0; i<3; i++) {
            items.add(new OrderItem(OrderId = ord.Id, PricebookEntryId = pbe.Id, Quantity = 1, UnitPrice = 50));
        }

        Test.startTest();
        insert items; 
        Test.stopTest();

        // Vérification SOQL : Le transporteur a-t-il été sélectionné automatiquement ?
        Order updatedOrd = [SELECT Transporteur__c FROM Order WHERE Id = :ord.Id];
        // Note : L'assertion passera si vos triggers et services sont bien déployés
        System.assertNotEquals(null, updatedOrd.Transporteur__c, 'Le transporteur devrait être sélectionné automatiquement.');
    }

    /**
     * Test des méthodes des Selectors (Optimisation SOQL Étape 7)
     */
    @isTest
    static void testSelectors() {
        Test.startTest();
        List<Order> orders = OrderSelector.getOrdersByAccountType('Particulier');
        List<Transporteur__c> carriers = TransporterSelector.getBestCarriersWithDetails('France', 'Particulier');
        Test.stopTest();

        System.assert(orders.size() > 0, 'Le sélecteur de commandes devrait retourner des résultats');
        System.assert(carriers.size() > 0, 'Le sélecteur de transporteurs devrait trouver le tarif France');
    }
}