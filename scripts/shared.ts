// shared.ts - Helper functions
import * as fs from 'fs';
import * as path from 'path';

export const saveData = (data: any, filename: string) => {
    try {
        const filePath = path.resolve(__dirname, filename);
        fs.writeFileSync(filePath, JSON.stringify(data));
    } catch (error) {
        console.error('Failed to save data:', error);
        throw error;
    }
};

export const loadData = (filename: string) => {
    try {
        const filePath = path.resolve(__dirname, filename);
        const data = fs.readFileSync(filePath, 'utf8');
        return JSON.parse(data);
    } catch (error) {
        console.error('Failed to load data:', error);
        throw error;
    }
};