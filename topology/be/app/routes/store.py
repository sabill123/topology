"""
Store routes
"""
from typing import List, Any
from fastapi import APIRouter, Depends, HTTPException, status, Query
from models.store import StoreItem, StoreCategory, Purchase, PurchaseCreate
from app.utils.auth import get_current_user_from_token
from app.utils.google_sheets import GoogleSheetsManager
from app.utils.redis_manager import RedisManager
import uuid

router = APIRouter(
    prefix="/store",
    tags=["store"]
)

# Initialize services
db = GoogleSheetsManager.get_instance()
redis_manager = RedisManager()

@router.get("/items", response_model=List[StoreItem])
async def get_store_items(
    category: StoreCategory = Query(None),
    min_price: int = Query(None, ge=0),
    max_price: int = Query(None, ge=0),
    search: str = Query(None),
    sort_by: str = Query("popularity", enum=["name", "price", "popularity", "created_at"]),
    order: str = Query("desc", enum=["asc", "desc"]),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Get store items with filters."""
    # Build filters
    filters = {"is_active": True}
    
    if category:
        filters["category"] = category
    
    # Get all items
    items = await db.query_items("store_items", filters)
    
    # Apply additional filters
    filtered_items = []
    for item in items:
        # Price filter
        if min_price is not None and item.get("price", 0) < min_price:
            continue
        if max_price is not None and item.get("price", 0) > max_price:
            continue
            
        # Search filter
        if search:
            search_lower = search.lower()
            if (search_lower not in item.get("name", "").lower() and
                search_lower not in item.get("description", "").lower()):
                continue
        
        filtered_items.append(item)
    
    # Sort items
    if sort_by == "name":
        filtered_items.sort(key=lambda x: x.get("name", ""))
    elif sort_by == "price":
        filtered_items.sort(key=lambda x: x.get("price", 0))
    elif sort_by == "popularity":
        filtered_items.sort(key=lambda x: x.get("purchase_count", 0))
    elif sort_by == "created_at":
        filtered_items.sort(key=lambda x: x.get("created_at", ""))
    
    # Apply order
    if order == "desc" and sort_by != "name":
        filtered_items.reverse()
    elif order == "asc" and sort_by == "name":
        filtered_items.reverse()
    
    # Apply pagination
    paginated_items = filtered_items[offset:offset + limit]
    
    return [StoreItem(**item) for item in paginated_items]

@router.get("/items/{item_id}", response_model=StoreItem)
async def get_store_item(
    item_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get a specific store item."""
    item = await db.get_item("store_items", item_id)
    
    if not item or not item.get("is_active", True):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found"
        )
    
    return StoreItem(**item)

@router.post("/purchase", response_model=Purchase)
async def purchase_item(
    purchase_data: PurchaseCreate,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Purchase a store item."""
    # Get item
    item = await db.get_item("store_items", purchase_data.item_id)
    
    if not item or not item.get("is_active", True):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Item not found"
        )
    
    # Check stock
    if item.get("stock", 0) < purchase_data.quantity:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Insufficient stock"
        )
    
    # Check if user has already purchased this item (if it's limited)
    if item.get("is_limited", False):
        existing_purchases = await db.query_items(
            "purchases",
            {
                "user_id": current_user["user_id"],
                "item_id": purchase_data.item_id,
                "status": "completed"
            }
        )
        
        if existing_purchases:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="You have already purchased this limited item"
            )
    
    # Calculate total cost
    total_cost = item["price"] * purchase_data.quantity
    
    # In a real app, process payment here
    # For now, just create the purchase record
    
    # Create purchase
    purchase_id = str(uuid.uuid4())
    new_purchase = {
        "purchase_id": purchase_id,
        "user_id": current_user["user_id"],
        "item_id": purchase_data.item_id,
        "quantity": purchase_data.quantity,
        "unit_price": item["price"],
        "total_price": total_cost,
        "status": "completed",  # In real app, this would be "pending" until payment
        "created_at": db._get_current_time()
    }
    
    await db.create_item("purchases", new_purchase)
    
    # Update item stock and purchase count
    new_stock = item.get("stock", 0) - purchase_data.quantity
    new_purchase_count = item.get("purchase_count", 0) + purchase_data.quantity
    
    await db.update_item(
        "store_items",
        purchase_data.item_id,
        {
            "stock": new_stock,
            "purchase_count": new_purchase_count,
            "updated_at": db._get_current_time()
        }
    )
    
    # Update user's premium status if applicable
    if item["category"] == StoreCategory.PREMIUM:
        # Extend premium subscription
        # This is simplified - in real app, handle subscription properly
        await db.update_item(
            "users",
            current_user["user_id"],
            {
                "account_type": "premium",
                "premium_expires_at": db._get_current_time(),  # Should calculate expiration
                "updated_at": db._get_current_time()
            }
        )
    
    return Purchase(**new_purchase)

@router.get("/purchases", response_model=List[Purchase])
async def get_purchase_history(
    current_user: dict = Depends(get_current_user_from_token),
    status: str = Query(None, enum=["pending", "completed", "failed", "refunded"]),
    limit: int = Query(20, ge=1, le=100),
    offset: int = Query(0, ge=0)
) -> Any:
    """Get user's purchase history."""
    # Build filters
    filters = {"user_id": current_user["user_id"]}
    
    if status:
        filters["status"] = status
    
    # Get purchases
    purchases = await db.query_items("purchases", filters)
    
    # Sort by created_at (most recent first)
    purchases.sort(key=lambda x: x["created_at"], reverse=True)
    
    # Apply pagination
    paginated_purchases = purchases[offset:offset + limit]
    
    return [Purchase(**purchase) for purchase in paginated_purchases]

@router.get("/purchases/{purchase_id}", response_model=Purchase)
async def get_purchase(
    purchase_id: str,
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get a specific purchase."""
    purchase = await db.get_item("purchases", purchase_id)
    
    if not purchase:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Purchase not found"
        )
    
    # Check if purchase belongs to current user
    if purchase["user_id"] != current_user["user_id"]:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="You can only view your own purchases"
        )
    
    return Purchase(**purchase)

@router.get("/categories", response_model=List[dict])
async def get_categories() -> Any:
    """Get all store categories with item counts."""
    categories = []
    
    for category in StoreCategory:
        # Count items in category
        items = await db.query_items(
            "store_items",
            {"category": category.value, "is_active": True}
        )
        
        categories.append({
            "name": category.value,
            "display_name": category.value.replace("_", " ").title(),
            "item_count": len(items)
        })
    
    return categories

@router.get("/featured", response_model=List[StoreItem])
async def get_featured_items(
    limit: int = Query(10, ge=1, le=20)
) -> Any:
    """Get featured store items."""
    # Get items marked as featured
    featured_items = await db.query_items(
        "store_items",
        {"is_featured": True, "is_active": True}
    )
    
    # Sort by popularity and created_at
    featured_items.sort(
        key=lambda x: (x.get("purchase_count", 0), x.get("created_at", "")),
        reverse=True
    )
    
    # Apply limit
    limited_items = featured_items[:limit]
    
    return [StoreItem(**item) for item in limited_items]

@router.get("/my-items", response_model=List[dict])
async def get_my_items(
    current_user: dict = Depends(get_current_user_from_token)
) -> Any:
    """Get items purchased by current user."""
    # Get user's completed purchases
    purchases = await db.query_items(
        "purchases",
        {"user_id": current_user["user_id"], "status": "completed"}
    )
    
    # Group by item_id and get item details
    item_purchases = {}
    
    for purchase in purchases:
        item_id = purchase["item_id"]
        
        if item_id not in item_purchases:
            # Get item details
            item = await db.get_item("store_items", item_id)
            
            if item:
                item_purchases[item_id] = {
                    "item": StoreItem(**item),
                    "quantity": 0,
                    "last_purchased": purchase["created_at"]
                }
        
        # Update quantity
        if item_id in item_purchases:
            item_purchases[item_id]["quantity"] += purchase["quantity"]
            
            # Update last purchased date
            if purchase["created_at"] > item_purchases[item_id]["last_purchased"]:
                item_purchases[item_id]["last_purchased"] = purchase["created_at"]
    
    # Convert to list and sort by last purchased
    my_items = list(item_purchases.values())
    my_items.sort(key=lambda x: x["last_purchased"], reverse=True)
    
    return my_items