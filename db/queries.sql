-- ============================================================================
-- ЗАДАЧА 1: Атомарный перевод средств с защитой от состояния гонки (Race Condition)
-- Интервьюер: "Как списать деньги со счета А и зачислить на Б, если параллельно 
-- пришли два запроса на списание последних 500 рублей?"
-- Решение: Использование SELECT ... FOR UPDATE (пессимистичная блокировка строки).
-- ============================================================================

BEGIN;

-- 1. Блокируем строки счетов в детерминированном порядке (по id), чтобы избежать Deadlock
SELECT id, balance, hold_amount 
FROM accounts 
WHERE id IN ('source-account-uuid', 'target-account-uuid')
ORDER BY id
FOR UPDATE;

-- 2. Проверяем доступный остаток (доступно = balance - hold_amount)
-- Если доступно < суммы перевода, приложение выполняет ROLLBACK.

-- 3. Создаем запись о переводе с уникальным idempotency_key
INSERT INTO transfers (idempotency_key, source_account_id, target_account_id, amount, currency, status)
VALUES ('idempotency-uuid', 'source-account-uuid', 'target-account-uuid', 500.00, 'RUB', 'PENDING');

-- 4. Резервируем средства (Hold)
UPDATE accounts 
SET hold_amount = hold_amount + 500.00 
WHERE id = 'source-account-uuid';

-- 5. Фиксируем проводку холда в леджере
INSERT INTO account_entries (transfer_id, account_id, entry_type, amount)
VALUES ('transfer-uuid', 'source-account-uuid', 'HOLD', 500.00);

COMMIT;


-- ============================================================================
-- ЗАДАЧА 2: Проверка консистентности баланса по леджеру
-- Интервьюер: "Как убедиться, что баланс счета в accounts совпадает с историей операций?"
-- ============================================================================

SELECT 
    a.id AS account_id,
    a.account_number,
    a.balance AS stored_balance,
    COALESCE(SUM(CASE 
        WHEN e.entry_type = 'CREDIT' THEN e.amount
        WHEN e.entry_type = 'DEBIT' THEN -e.amount
        ELSE 0 
    END), 0) AS calculated_ledger_balance
FROM accounts a
LEFT JOIN account_entries e ON a.id = e.account_id
WHERE a.id = 'source-account-uuid'
GROUP BY a.id, a.account_number, a.balance;


-- ============================================================================
-- ЗАДАЧА 3: Оконная функция для аналитики (Классика SQL-секции)
-- Интервьюер: "Выведи топ-3 самых крупных успешных перевода для каждого счета за последний месяц"
-- Решение: Использование DENSE_RANK() OVER (PARTITION BY ... ORDER BY ...).
-- ============================================================================

WITH ranked_transfers AS (
    SELECT 
        source_account_id,
        id AS transfer_id,
        amount,
        created_at,
        DENSE_RANK() OVER (
            PARTITION BY source_account_id 
            ORDER BY amount DESC
        ) AS rank_num
    FROM transfers
    WHERE status = 'SUCCESS'
      AND created_at >= NOW() - INTERVAL '30 days'
)
SELECT 
    source_account_id,
    transfer_id,
    amount,
    created_at,
    rank_num
FROM ranked_transfers
WHERE rank_num <= 3
ORDER BY source_account_id, rank_num;