-- =====================================================
-- База данных: Металлургическое производство (MES)
-- Автор:
-- Описание: Таблицы для учета плавок, материалов и качества
-- =====================================================

-- Удаление старых таблиц (если существуют) в правильном порядке
DROP TABLE IF EXISTS write_off_materials CASCADE;
DROP TABLE IF EXISTS quality_certificate CASCADE;
DROP TABLE IF EXISTS material_request_items CASCADE;
DROP TABLE IF EXISTS material_requests CASCADE;
DROP TABLE IF EXISTS melting_order CASCADE;
DROP TABLE IF EXISTS contract_specifications CASCADE;
DROP TABLE IF EXISTS contracts CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS materials CASCADE;
DROP TABLE IF EXISTS steel_grades CASCADE;

-- =====================================================
-- 1. Справочники
-- =====================================================

-- Таблица марок стали
CREATE TABLE steel_grades (
    id SERIAL PRIMARY KEY,
    grade_name VARCHAR(50) NOT NULL UNIQUE, -- Ст3, 09Г2С, 12Х18Н10Т
    gost VARCHAR(50), -- ГОСТ 380-2005 и т.д.
    carbon_min DECIMAL(5,3),
    carbon_max DECIMAL(5,3),
    manganese_min DECIMAL(5,3),
    manganese_max DECIMAL(5,3),
    silicon_min DECIMAL(5,3),
    silicon_max DECIMAL(5,3),
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица материалов (шихта, ферросплавы)
CREATE TABLE materials (
    id SERIAL PRIMARY KEY,
    material_code VARCHAR(20) UNIQUE NOT NULL, -- Артикул
    material_name VARCHAR(100) NOT NULL, -- Чугун передельный, лом 3А, ферромарганец
    category VARCHAR(50), -- Основное, легирующее, флюсы
    unit VARCHAR(10) NOT NULL, -- т, кг
    price_per_ton DECIMAL(12,2), -- Цена за тонну в рублях
    stock_balance DECIMAL(10,3) DEFAULT 0, -- Текущий остаток на складе
    warehouse_location VARCHAR(50), -- Ячейка склада
    supplier VARCHAR(100),
    is_active BOOLEAN DEFAULT true
);

-- =====================================================
-- 2. Коммерческий блок
-- =====================================================

-- Таблица заказчиков
CREATE TABLE customers (
    id SERIAL PRIMARY KEY,
    customer_type VARCHAR(20) CHECK (customer_type IN ('Юрлицо', 'ИП', 'Физлицо')),
    full_name VARCHAR(200) NOT NULL,
    inn VARCHAR(12),
    kpp VARCHAR(9),
    legal_address TEXT,
    actual_address TEXT,
    contact_person VARCHAR(100),
    phone VARCHAR(20),
    email VARCHAR(100),
    bank_name VARCHAR(200),
    bank_account VARCHAR(30),
    corr_account VARCHAR(30),
    bic VARCHAR(9),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Таблица договоров
CREATE TABLE contracts (
    id SERIAL PRIMARY KEY,
    contract_number VARCHAR(50) NOT NULL UNIQUE,
    contract_date DATE NOT NULL,
    customer_id INTEGER REFERENCES customers(id),
    contract_sum DECIMAL(15,2),
    currency VARCHAR(3) DEFAULT 'RUB',
    start_date DATE,
    end_date DATE,
    status VARCHAR(20) DEFAULT 'Черновик' CHECK (status IN ('Черновик', 'Подписан', 'Исполняется', 'Закрыт', 'Расторгнут')),
    file_link TEXT, -- Ссылка на скан договора
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Спецификации к договору (позиции заказа)
CREATE TABLE contract_specifications (
    id SERIAL PRIMARY KEY,
    contract_id INTEGER REFERENCES contracts(id) ON DELETE CASCADE,
    position_number INTEGER NOT NULL, -- Номер позиции
    steel_grade_id INTEGER REFERENCES steel_grades(id), -- Марка стали
    profile_type VARCHAR(50), -- Лист, круг, арматура, балка
    profile_size VARCHAR(50), -- 10мм, 20х20, 100х50х4
    quantity_ton DECIMAL(10,3) NOT NULL, -- Вес в тоннах
    price_per_ton DECIMAL(12,2),
    total_amount DECIMAL(15,2),
    delivery_date DATE,
    status VARCHAR(20) DEFAULT 'К производству'
);

-- =====================================================
-- 3. Производственный блок
-- =====================================================

-- Заказы на плавку (аналог "проектов")
CREATE TABLE melting_order (
    id SERIAL PRIMARY KEY,
    order_number VARCHAR(50) NOT NULL UNIQUE, -- Номер заказа-наряда
    specification_id INTEGER REFERENCES contract_specifications(id),
    steel_grade_id INTEGER REFERENCES steel_grades(id),
    target_weight DECIMAL(10,3) NOT NULL, -- Плановая масса
    actual_weight DECIMAL(10,3), -- Фактическая масса
    furnace_number INTEGER, -- Номер печи
    shift INTEGER CHECK (shift IN (1,2,3)), -- Смена
    master_name VARCHAR(100), -- ФИО мастера
    start_time TIMESTAMP,
    end_time TIMESTAMP,
    status VARCHAR(30) DEFAULT 'Создан' CHECK (status IN ('Создан', 'Назначен', 'В процессе', 'Выплавлен', 'Разлит', 'На контроле', 'Годен', 'Брак')),
    chemical_analysis_id INTEGER, -- Ссылка на хим. анализ (отдельно)
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Заявки на материалы (шихтовка)
CREATE TABLE material_requests (
    id SERIAL PRIMARY KEY,
    request_number VARCHAR(50) NOT NULL UNIQUE,
    melting_order_id INTEGER REFERENCES melting_order(id) ON DELETE CASCADE,
    request_date DATE DEFAULT CURRENT_DATE,
    requested_by VARCHAR(100), -- Кто запросил
    status VARCHAR(20) DEFAULT 'Новая' CHECK (status IN ('Новая', 'Утверждена', 'Выдана', 'Отменена')),
    approved_by VARCHAR(100),
    approved_date DATE,
    notes TEXT
);

-- Строки заявки (какие материалы и сколько)
CREATE TABLE material_request_items (
    id SERIAL PRIMARY KEY,
    request_id INTEGER REFERENCES material_requests(id) ON DELETE CASCADE,
    material_id INTEGER REFERENCES materials(id),
    planned_quantity DECIMAL(10,3) NOT NULL, -- План по технологии
    actual_issued DECIMAL(10,3) DEFAULT 0, -- Фактически выдали
    unit VARCHAR(10) NOT NULL,
    notes TEXT
);

-- =====================================================
-- 4. Учет готовой продукции и качество
-- =====================================================

-- Сертификаты качества (аналог КС-2/актов)
CREATE TABLE quality_certificate (
    id SERIAL PRIMARY KEY,
    certificate_number VARCHAR(50) NOT NULL UNIQUE,
    melting_order_id INTEGER REFERENCES melting_order(id) UNIQUE, -- Один сертификат на плавку
    issue_date DATE DEFAULT CURRENT_DATE,
    steel_grade_id INTEGER REFERENCES steel_grades(id),

    -- Химический состав (фактический)
    c_actual DECIMAL(5,3),
    si_actual DECIMAL(5,3),
    mn_actual DECIMAL(5,3),
    s_actual DECIMAL(5,3),
    p_actual DECIMAL(5,3),
    cr_actual DECIMAL(5,3),
    ni_actual DECIMAL(5,3),
    cu_actual DECIMAL(5,3),

    -- Механические свойства
    yield_strength DECIMAL(8,2), -- Предел текучести
    tensile_strength DECIMAL(8,2), -- Временное сопротивление
    elongation DECIMAL(5,2), -- Относительное удлинение

    -- Результат
    conclusion VARCHAR(50) DEFAULT 'Соответствует' CHECK (conclusion IN ('Соответствует', 'Не соответствует', 'Условно годен')),
    otk_stamp BOOLEAN DEFAULT false, -- Отметка ОТК
    pdf_file TEXT, -- Ссылка на скан
    created_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Списание материалов на плавку (фактический расход)
CREATE TABLE write_off_materials (
    id SERIAL PRIMARY KEY,
    write_off_number VARCHAR(50) NOT NULL UNIQUE,
    melting_order_id INTEGER REFERENCES melting_order(id) ON DELETE CASCADE,
    write_off_date DATE DEFAULT CURRENT_DATE,
    material_id INTEGER REFERENCES materials(id),
    quantity DECIMAL(10,3) NOT NULL, -- Количество списанных тонн/кг
    unit VARCHAR(10) NOT NULL,
    price_per_unit DECIMAL(12,2), -- Цена на момент списания
    total_cost DECIMAL(15,2) GENERATED ALWAYS AS (quantity * price_per_unit) STORED,
    reason VARCHAR(50) DEFAULT 'Производство',
    write_off_by VARCHAR(100), -- Кто списал
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Создание индексов для ускорения поиска
CREATE INDEX idx_contracts_customer ON contracts(customer_id);
CREATE INDEX idx_melting_order_status ON melting_order(status);
CREATE INDEX idx_certificate_date ON quality_certificate(issue_date);
CREATE INDEX idx_write_off_material ON write_off_materials(material_id);

-- Комментарии к таблицам
COMMENT ON TABLE melting_order IS 'Заказы на плавку - основной производственный документ';
COMMENT ON TABLE quality_certificate IS 'Сертификаты качества (паспорта) на готовую продукцию';
COMMENT ON TABLE write_off_materials IS 'Фактическое списание сырья и материалов в производство';

-- =====================================================
-- Инициализация: начальные данные
-- =====================================================

-- Добавим несколько марок стали
INSERT INTO steel_grades (grade_name, gost, carbon_min, carbon_max, manganese_min, manganese_max) VALUES
    ('Ст3сп', 'ГОСТ 380-2005', 0.14, 0.22, 0.40, 0.65),
    ('09Г2С', 'ГОСТ 19281-2014', 0.10, 0.15, 1.30, 1.70),
    ('12Х18Н10Т', 'ГОСТ 5632-2014', 0.08, 0.12, 1.00, 2.00);

-- Добавим несколько материалов
INSERT INTO materials (material_code, material_name, category, unit, price_per_ton, stock_balance) VALUES
    ('RM001', 'Чугун передельный П1', 'Основное', 'т', 35000.00, 1500.500),
    ('RM002', 'Лом стальной 3А', 'Основное', 'т', 28000.00, 850.200),
    ('RM003', 'Ферромарганец ФМн78', 'Легирующее', 'т', 125000.00, 45.800),
    ('RM004', 'Ферросилиций ФС65', 'Легирующее', 'т', 98000.00, 32.400),
    ('RM005', 'Известь комовая', 'Флюсы', 'т', 5500.00, 210.000);