/**
 * Trigger sur l'objet OrderItem (Produit de commande)
 * Automatise la sélection du transporteur en fonction des changements de produits.
 */
trigger OrderItemTrigger on OrderItem (after insert, after update, after delete) {
    
    // On utilise le contexte "After" car on a besoin que les produits soient 
    // calculés en base pour définir le meilleur transporteur sur la commande parente.
    if (Trigger.isAfter) {
        // On récupère la liste des produits impactés (ceux insérés/modifiés ou ceux supprimés)
        List<OrderItem> affectedItems = Trigger.isDelete ? Trigger.old : Trigger.new;
        
        // Appel de la logique de sélection automatique dans le service
        OrderService.autoSelectBestCarrier(affectedItems);
    }
}