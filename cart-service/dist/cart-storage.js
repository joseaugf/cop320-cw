"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.getCart = getCart;
exports.addItem = addItem;
exports.updateItem = updateItem;
exports.removeItem = removeItem;
exports.clearCart = clearCart;
const redis_client_1 = require("./redis-client");
const types_1 = require("./types");
const api_1 = require("@opentelemetry/api");
const tracer = api_1.trace.getTracer('cart-service');
const CART_TTL = 24 * 60 * 60; // 24 hours in seconds
/**
 * Validate cart item data
 */
function validateCartItem(item) {
    if (!item.productId || typeof item.productId !== 'string') {
        throw new types_1.ValidationError('Product ID is required and must be a string');
    }
    if (!item.name || typeof item.name !== 'string') {
        throw new types_1.ValidationError('Product name is required and must be a string');
    }
    if (typeof item.price !== 'number' || item.price <= 0) {
        throw new types_1.ValidationError('Price must be a positive number');
    }
    if (typeof item.quantity !== 'number' || item.quantity <= 0 || !Number.isInteger(item.quantity)) {
        throw new types_1.ValidationError('Quantity must be a positive integer');
    }
}
/**
 * Calculate cart total
 */
function calculateTotal(items) {
    return items.reduce((sum, item) => sum + (item.price * item.quantity), 0);
}
/**
 * Get Redis key for cart
 */
function getCartKey(sessionId) {
    return `cart:${sessionId}`;
}
/**
 * Get cart by session ID
 */
async function getCart(sessionId) {
    return tracer.startActiveSpan('cart.get', async (span) => {
        try {
            span.setAttribute('session.id', sessionId);
            const key = getCartKey(sessionId);
            const data = await redis_client_1.redisClient.get(key);
            if (!data) {
                // Return empty cart
                const emptyCart = {
                    sessionId,
                    items: [],
                    total: 0,
                    updatedAt: new Date(),
                };
                span.setAttribute('cart.empty', true);
                return emptyCart;
            }
            const cart = JSON.parse(data);
            cart.updatedAt = new Date(cart.updatedAt);
            span.setAttribute('cart.items.count', cart.items.length);
            span.setAttribute('cart.total', cart.total);
            return cart;
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
/**
 * Save cart to Redis
 */
async function saveCart(cart) {
    return tracer.startActiveSpan('cart.save', async (span) => {
        try {
            span.setAttribute('session.id', cart.sessionId);
            span.setAttribute('cart.items.count', cart.items.length);
            const key = getCartKey(cart.sessionId);
            cart.updatedAt = new Date();
            await redis_client_1.redisClient.setEx(key, CART_TTL, JSON.stringify(cart));
            span.setAttribute('cart.ttl', CART_TTL);
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
/**
 * Add item to cart
 */
async function addItem(sessionId, item) {
    return tracer.startActiveSpan('cart.addItem', async (span) => {
        try {
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', item.productId);
            span.setAttribute('quantity', item.quantity);
            validateCartItem(item);
            const cart = await getCart(sessionId);
            // Check if item already exists
            const existingItemIndex = cart.items.findIndex(i => i.productId === item.productId);
            if (existingItemIndex >= 0) {
                // Update quantity
                cart.items[existingItemIndex].quantity += item.quantity;
                span.setAttribute('cart.item.updated', true);
            }
            else {
                // Add new item
                cart.items.push(item);
                span.setAttribute('cart.item.added', true);
            }
            cart.total = calculateTotal(cart.items);
            await saveCart(cart);
            span.setAttribute('cart.total', cart.total);
            return cart;
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
/**
 * Update item quantity in cart
 */
async function updateItem(sessionId, productId, quantity) {
    return tracer.startActiveSpan('cart.updateItem', async (span) => {
        try {
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', productId);
            span.setAttribute('quantity', quantity);
            if (typeof quantity !== 'number' || quantity <= 0 || !Number.isInteger(quantity)) {
                throw new types_1.ValidationError('Quantity must be a positive integer');
            }
            const cart = await getCart(sessionId);
            const itemIndex = cart.items.findIndex(i => i.productId === productId);
            if (itemIndex < 0) {
                throw new types_1.NotFoundError(`Item with product ID ${productId} not found in cart`);
            }
            cart.items[itemIndex].quantity = quantity;
            cart.total = calculateTotal(cart.items);
            await saveCart(cart);
            span.setAttribute('cart.total', cart.total);
            return cart;
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
/**
 * Remove item from cart
 */
async function removeItem(sessionId, productId) {
    return tracer.startActiveSpan('cart.removeItem', async (span) => {
        try {
            span.setAttribute('session.id', sessionId);
            span.setAttribute('product.id', productId);
            const cart = await getCart(sessionId);
            const itemIndex = cart.items.findIndex(i => i.productId === productId);
            if (itemIndex < 0) {
                throw new types_1.NotFoundError(`Item with product ID ${productId} not found in cart`);
            }
            cart.items.splice(itemIndex, 1);
            cart.total = calculateTotal(cart.items);
            await saveCart(cart);
            span.setAttribute('cart.items.count', cart.items.length);
            span.setAttribute('cart.total', cart.total);
            return cart;
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
/**
 * Clear cart
 */
async function clearCart(sessionId) {
    return tracer.startActiveSpan('cart.clear', async (span) => {
        try {
            span.setAttribute('session.id', sessionId);
            const key = getCartKey(sessionId);
            await redis_client_1.redisClient.del(key);
            span.setAttribute('cart.cleared', true);
        }
        catch (error) {
            span.recordException(error);
            throw error;
        }
        finally {
            span.end();
        }
    });
}
