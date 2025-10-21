"""Seed data script to populate the catalog with initial products."""

from sqlalchemy.orm import Session
from .models import Product
from .database import SessionLocal, engine, Base


SEED_PRODUCTS = [
    {
        "name": "Premium Dog Food - Chicken & Rice",
        "description": "High-quality dry dog food with real chicken and brown rice. Perfect for adult dogs of all breeds.",
        "price": 49.99,
        "category": "food",
        "image_url": "https://images.unsplash.com/photo-1589924691995-400dc9ecc119",
        "stock": 50
    },
    {
        "name": "Cat Food - Salmon Delight",
        "description": "Nutritious wet cat food with real salmon. Rich in omega-3 fatty acids for healthy skin and coat.",
        "price": 29.99,
        "category": "food",
        "image_url": "https://images.unsplash.com/photo-1589924691995-400dc9ecc119",
        "stock": 75
    },
    {
        "name": "Interactive Squeaky Ball",
        "description": "Durable rubber ball with built-in squeaker. Great for fetch and interactive play.",
        "price": 12.99,
        "category": "toys",
        "image_url": "https://images.unsplash.com/photo-1535294435445-d7249524ef2e",
        "stock": 100
    },
    {
        "name": "Catnip Mouse Toy Set",
        "description": "Set of 3 plush mice filled with premium catnip. Hours of entertainment for your feline friend.",
        "price": 15.99,
        "category": "toys",
        "image_url": "https://images.unsplash.com/photo-1535294435445-d7249524ef2e",
        "stock": 80
    },
    {
        "name": "Rope Tug Toy",
        "description": "Heavy-duty cotton rope toy for dogs. Perfect for tug-of-war and dental health.",
        "price": 9.99,
        "category": "toys",
        "image_url": "https://images.unsplash.com/photo-1535294435445-d7249524ef2e",
        "stock": 60
    },
    {
        "name": "Adjustable Dog Collar - Blue",
        "description": "Comfortable nylon collar with quick-release buckle. Adjustable for dogs 15-25 lbs.",
        "price": 18.99,
        "category": "accessories",
        "image_url": "https://images.unsplash.com/photo-1601758228041-f3b2795255f1",
        "stock": 45
    },
    {
        "name": "Reflective Cat Collar with Bell",
        "description": "Safety collar with reflective strips and bell. Breakaway design for cat safety.",
        "price": 11.99,
        "category": "accessories",
        "image_url": "https://images.unsplash.com/photo-1601758228041-f3b2795255f1",
        "stock": 55
    },
    {
        "name": "Retractable Dog Leash",
        "description": "16-foot retractable leash with comfortable grip handle. Suitable for dogs up to 50 lbs.",
        "price": 24.99,
        "category": "accessories",
        "image_url": "https://images.unsplash.com/photo-1601758228041-f3b2795255f1",
        "stock": 40
    },
    {
        "name": "Orthopedic Dog Bed - Large",
        "description": "Memory foam dog bed with removable washable cover. Ideal for senior dogs and large breeds.",
        "price": 79.99,
        "category": "beds",
        "image_url": "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e",
        "stock": 25
    },
    {
        "name": "Cozy Cat Cave Bed",
        "description": "Soft felt cave bed for cats. Provides privacy and warmth for your feline companion.",
        "price": 39.99,
        "category": "beds",
        "image_url": "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e",
        "stock": 30
    },
    {
        "name": "Heated Pet Mat",
        "description": "Self-warming pet mat with thermal core. No electricity needed, perfect for cold weather.",
        "price": 34.99,
        "category": "beds",
        "image_url": "https://images.unsplash.com/photo-1583511655857-d19b40a7a54e",
        "stock": 35
    },
    {
        "name": "Puppy Training Treats",
        "description": "Small, soft training treats perfect for puppies. Made with natural ingredients.",
        "price": 14.99,
        "category": "food",
        "image_url": "https://images.unsplash.com/photo-1589924691995-400dc9ecc119",
        "stock": 90
    }
]


def seed_database():
    """Seed the database with initial product data."""
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    
    # Create session
    db = SessionLocal()
    
    try:
        # Check if products already exist
        existing_count = db.query(Product).count()
        
        if existing_count > 0:
            print(f"Database already contains {existing_count} products. Skipping seed.")
            return
        
        # Add seed products
        for product_data in SEED_PRODUCTS:
            product = Product(**product_data)
            db.add(product)
        
        db.commit()
        print(f"Successfully seeded {len(SEED_PRODUCTS)} products to the database.")
        
    except Exception as e:
        print(f"Error seeding database: {e}")
        db.rollback()
    finally:
        db.close()


if __name__ == "__main__":
    seed_database()
