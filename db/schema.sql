-- Включение расширения для генерации UUID
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Таблица пользователей
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) NOT NULL UNIQUE,
    phone VARCHAR(20) NOT NULL UNIQUE,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Таблица счетов пользователей
CREATE TABLE accounts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    account_number VARCHAR(34) NOT NULL UNIQUE,
    currency VARCHAR(3) NOT NULL CHECK (currency IN ('RUB', 'USD', 'EUR')),
    balance NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    hold_amount NUMERIC(15, 2) NOT NULL DEFAULT 0.00,
    status VARCHAR(32) NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    
    -- Контроль неотрицательного баланса и холда
    CONSTRAINT chk_positive_balance CHECK (balance >= 0),
    CONSTRAINT chk_positive_hold CHECK (hold_amount >= 0),
    CONSTRAINT chk_available_funds CHECK (balance >= hold_amount)
);

-- Таблица транзакций переводов
CREATE TABLE transfers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    idempotency_key UUID NOT NULL UNIQUE,
    source_account_id UUID NOT NULL REFERENCES accounts(id),
    target_account_id UUID NOT NULL REFERENCES accounts(id),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    currency VARCHAR(3) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'NEW',
    external_gateway_id VARCHAR(64),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Таблица проводок (Ledger / Двойная запись)
CREATE TABLE account_entries (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    transfer_id UUID NOT NULL REFERENCES transfers(id) ON DELETE RESTRICT,
    account_id UUID NOT NULL REFERENCES accounts(id) ON DELETE RESTRICT,
    entry_type VARCHAR(16) NOT NULL CHECK (entry_type IN ('HOLD', 'DEBIT', 'CREDIT', 'UNHOLD')),
    amount NUMERIC(15, 2) NOT NULL CHECK (amount > 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Индексы для оптимизации поиска и истории
CREATE INDEX idx_transfers_source_account ON transfers(source_account_id);
CREATE INDEX idx_transfers_created_at ON transfers(created_at);
CREATE INDEX idx_account_entries_account_id ON account_entries(account_id);