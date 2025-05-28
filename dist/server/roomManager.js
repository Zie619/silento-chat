import { WebSocket } from 'ws';
export class RoomManager {
    rooms = new Map();
    ROOM_EXPIRY_TIME = 5 * 60 * 1000; // 5 minutes
    CLEANUP_INTERVAL = 60 * 1000; // 1 minute
    constructor() {
        this.startCleanupInterval();
    }
    createRoom() {
        const roomId = this.generateRoomId();
        const room = {
            id: roomId,
            clients: new Map(),
            createdAt: Date.now(),
            lastActivity: Date.now()
        };
        this.rooms.set(roomId, room);
        console.log(`Room created: ${roomId}`);
        return roomId;
    }
    getRoom(roomId) {
        return this.rooms.get(roomId);
    }
    addClientToRoom(roomId, clientId, ws) {
        const room = this.rooms.get(roomId);
        if (!room) {
            throw new Error('Room not found');
        }
        if (ws) {
            room.clients.set(clientId, ws);
        }
        room.lastActivity = Date.now();
        return Array.from(room.clients.keys());
    }
    removeClientFromRoom(roomId, clientId) {
        const room = this.rooms.get(roomId);
        if (!room)
            return;
        room.clients.delete(clientId);
        room.lastActivity = Date.now();
        // Remove room if empty
        if (room.clients.size === 0) {
            this.rooms.delete(roomId);
            console.log(`Room ${roomId} removed - empty`);
        }
    }
    getRoomClients(roomId) {
        const room = this.rooms.get(roomId);
        return room ? Array.from(room.clients.keys()) : [];
    }
    broadcastToRoom(roomId, message, excludeClientId) {
        const room = this.rooms.get(roomId);
        if (!room)
            return;
        const messageStr = JSON.stringify(message);
        for (const [clientId, ws] of room.clients.entries()) {
            if (clientId !== excludeClientId && ws.readyState === WebSocket.OPEN) {
                try {
                    ws.send(messageStr);
                }
                catch (error) {
                    console.error(`Error sending message to client ${clientId}:`, error);
                    // Remove disconnected client
                    room.clients.delete(clientId);
                }
            }
        }
        room.lastActivity = Date.now();
    }
    generateRoomId() {
        // Generate a 6-character alphanumeric room ID
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let result = '';
        for (let i = 0; i < 6; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        // Ensure uniqueness
        if (this.rooms.has(result)) {
            return this.generateRoomId();
        }
        return result;
    }
    startCleanupInterval() {
        setInterval(() => {
            const now = Date.now();
            const expiredRooms = [];
            for (const [roomId, room] of this.rooms.entries()) {
                if (now - room.lastActivity > this.ROOM_EXPIRY_TIME) {
                    expiredRooms.push(roomId);
                }
            }
            for (const roomId of expiredRooms) {
                const room = this.rooms.get(roomId);
                if (room) {
                    // Close all WebSocket connections
                    for (const ws of room.clients.values()) {
                        try {
                            ws.close();
                        }
                        catch (error) {
                            console.error('Error closing WebSocket:', error);
                        }
                    }
                    this.rooms.delete(roomId);
                    console.log(`Room ${roomId} expired and removed`);
                }
            }
        }, this.CLEANUP_INTERVAL);
    }
    getRoomCount() {
        return this.rooms.size;
    }
    getTotalClients() {
        let total = 0;
        for (const room of this.rooms.values()) {
            total += room.clients.size;
        }
        return total;
    }
}
