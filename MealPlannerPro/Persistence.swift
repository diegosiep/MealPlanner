import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let viewContext = result.container.viewContext
        
        // Create sample food data
        let sampleFood = Food(context: viewContext)
        sampleFood.name = "Apple"
        sampleFood.fdcId = 123456
        sampleFood.calories = 52
        sampleFood.protein = 0.3
        sampleFood.carbs = 14
        sampleFood.fat = 0.2
        sampleFood.fiber = 2.4
        sampleFood.sodium = 1
        sampleFood.servingSize = 100
        sampleFood.servingSizeUnit = "g"
        sampleFood.dataType = "Foundation"
        sampleFood.brandOwner = nil
        sampleFood.dateAdded = Date()
        
        // Create a sample meal
        let sampleMeal = Meal(context: viewContext)
        sampleMeal.name = "Healthy Breakfast"
        sampleMeal.date = Date()
        sampleMeal.totalCalories = 300
        sampleMeal.mealType = "breakfast"
        
        // Create a connection between meal and food
        let mealFood = MealFood(context: viewContext)
        mealFood.quantity = 2.0
        mealFood.unit = "medium"
        mealFood.food = sampleFood
        mealFood.meal = sampleMeal
        
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
        
        return result
    }()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "MealPlannerPro")
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}
