CREATE SEQUENCE IF NOT EXISTS project_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS invoice_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS contract_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS purchase_order_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS credit_note_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS change_order_code_seq START 1;
CREATE SEQUENCE IF NOT EXISTS procurement_request_code_seq START 1;
CREATE TABLE IF NOT EXISTS users (
 id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE, password_hash TEXT NOT NULL,
 role TEXT NOT NULL DEFAULT 'employee' CHECK (role IN ('owner','admin','project_manager','engineer','accountant','purchasing','storekeeper','hr','sales','employee')),
 permissions JSONB NOT NULL DEFAULT '{}'::jsonb, active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS sessions (
 token_hash TEXT PRIMARY KEY, user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
 expires_at TIMESTAMPTZ NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS login_attempts (
 id BIGSERIAL PRIMARY KEY, email TEXT NOT NULL, attempted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_login_attempts_email_date ON login_attempts(email,attempted_at);
ALTER TABLE login_attempts ADD COLUMN IF NOT EXISTS ip_address TEXT NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS idx_login_attempts_ip_date ON login_attempts(ip_address,attempted_at);
CREATE TABLE IF NOT EXISTS customers (
 id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
 kind TEXT NOT NULL DEFAULT 'عميل', stage TEXT NOT NULL DEFAULT 'عميل جديد', source TEXT NOT NULL DEFAULT '', owner_user_id BIGINT REFERENCES users(id), notes TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS projects (
 id BIGSERIAL PRIMARY KEY, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, customer_id BIGINT REFERENCES customers(id), property_type TEXT NOT NULL DEFAULT '',
 address TEXT NOT NULL DEFAULT '', area NUMERIC(14,2) NOT NULL DEFAULT 0, finish_type TEXT NOT NULL DEFAULT '', contract_value NUMERIC(16,2) NOT NULL DEFAULT 0,
 start_date DATE, due_date DATE, manager_user_id BIGINT REFERENCES users(id), status TEXT NOT NULL DEFAULT 'جديد', progress NUMERIC(5,2) NOT NULL DEFAULT 0,
 budget NUMERIC(16,2) NOT NULL DEFAULT 0, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS boq_items (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), section TEXT NOT NULL DEFAULT '', name TEXT NOT NULL,
 description TEXT NOT NULL DEFAULT '', location TEXT NOT NULL DEFAULT '', length NUMERIC(14,3) NOT NULL DEFAULT 0, width NUMERIC(14,3) NOT NULL DEFAULT 0,
 height NUMERIC(14,3) NOT NULL DEFAULT 0, formula TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT 'م²', quantity NUMERIC(14,3) NOT NULL DEFAULT 0,
 material_rate NUMERIC(16,2) NOT NULL DEFAULT 0, labor_rate NUMERIC(16,2) NOT NULL DEFAULT 0, waste_percent NUMERIC(6,2) NOT NULL DEFAULT 0,
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS contracts (
 id BIGSERIAL PRIMARY KEY, number TEXT NOT NULL UNIQUE, project_id BIGINT NOT NULL REFERENCES projects(id), boq_version TEXT NOT NULL DEFAULT '1',
 total NUMERIC(16,2) NOT NULL, duration_days INTEGER NOT NULL DEFAULT 0, start_date DATE, due_date DATE, scope TEXT NOT NULL DEFAULT '', terms TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'مسودة', approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS installments (
 id BIGSERIAL PRIMARY KEY, contract_id BIGINT NOT NULL REFERENCES contracts(id), title TEXT NOT NULL, amount NUMERIC(16,2) NOT NULL,
 due_date DATE, status TEXT NOT NULL DEFAULT 'مستحقة', invoice_id BIGINT, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS change_orders (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), number TEXT NOT NULL UNIQUE, description TEXT NOT NULL,
 price_delta NUMERIC(16,2) NOT NULL DEFAULT 0, days_delta INTEGER NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'بانتظار الموافقة', approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS suppliers (
 id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', address TEXT NOT NULL DEFAULT '',
 categories TEXT NOT NULL DEFAULT '', tax_number TEXT NOT NULL DEFAULT '', rating NUMERIC(3,2), notes TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS materials (
 id BIGSERIAL PRIMARY KEY, sku TEXT NOT NULL UNIQUE, name TEXT NOT NULL, category TEXT NOT NULL DEFAULT '', unit TEXT NOT NULL DEFAULT 'قطعة',
 min_stock NUMERIC(14,3) NOT NULL DEFAULT 0, average_cost NUMERIC(16,2) NOT NULL DEFAULT 0, default_supplier_id BIGINT REFERENCES suppliers(id), active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS warehouses (
 id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, project_id BIGINT REFERENCES projects(id), address TEXT NOT NULL DEFAULT '', active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS stock_movements (
 id BIGSERIAL PRIMARY KEY, material_id BIGINT NOT NULL REFERENCES materials(id), warehouse_id BIGINT NOT NULL REFERENCES warehouses(id),
 project_id BIGINT REFERENCES projects(id), kind TEXT NOT NULL CHECK(kind IN ('receipt','issue','transfer_in','transfer_out','return','adjustment')),
 quantity NUMERIC(14,3) NOT NULL CHECK(quantity>0), unit_cost NUMERIC(16,2) NOT NULL DEFAULT 0, reference TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
 created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS purchase_orders (
 id BIGSERIAL PRIMARY KEY, number TEXT NOT NULL UNIQUE, supplier_id BIGINT NOT NULL REFERENCES suppliers(id), project_id BIGINT REFERENCES projects(id),
 warehouse_id BIGINT REFERENCES warehouses(id), status TEXT NOT NULL DEFAULT 'مسودة', order_date DATE NOT NULL DEFAULT CURRENT_DATE,
 expected_date DATE, subtotal NUMERIC(16,2) NOT NULL DEFAULT 0, tax NUMERIC(16,2) NOT NULL DEFAULT 0, transport NUMERIC(16,2) NOT NULL DEFAULT 0,
 total NUMERIC(16,2) NOT NULL DEFAULT 0, notes TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS purchase_order_items (
 id BIGSERIAL PRIMARY KEY, purchase_order_id BIGINT NOT NULL REFERENCES purchase_orders(id) ON DELETE CASCADE,
 material_id BIGINT REFERENCES materials(id), description TEXT NOT NULL, quantity NUMERIC(14,3) NOT NULL,
 unit TEXT NOT NULL DEFAULT '', unit_price NUMERIC(16,2) NOT NULL, total NUMERIC(16,2) NOT NULL
);
CREATE TABLE IF NOT EXISTS invoices (
 id BIGSERIAL PRIMARY KEY, number TEXT NOT NULL UNIQUE, project_id BIGINT NOT NULL REFERENCES projects(id), customer_id BIGINT NOT NULL REFERENCES customers(id),
 kind TEXT NOT NULL DEFAULT 'فاتورة تفصيلية', status TEXT NOT NULL DEFAULT 'مسودة', issue_date DATE NOT NULL DEFAULT CURRENT_DATE, due_date DATE,
 subtotal NUMERIC(16,2) NOT NULL DEFAULT 0, discount NUMERIC(16,2) NOT NULL DEFAULT 0, tax_rate NUMERIC(6,2) NOT NULL DEFAULT 0,
 total NUMERIC(16,2) NOT NULL DEFAULT 0, notes TEXT NOT NULL DEFAULT '', approved_by BIGINT REFERENCES users(id), approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS invoice_items (
 id BIGSERIAL PRIMARY KEY, invoice_id BIGINT NOT NULL REFERENCES invoices(id) ON DELETE CASCADE, boq_item_id BIGINT REFERENCES boq_items(id),
 name TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', location TEXT NOT NULL DEFAULT '', quantity NUMERIC(14,3) NOT NULL,
 length NUMERIC(14,3) NOT NULL DEFAULT 0, width NUMERIC(14,3) NOT NULL DEFAULT 0, height NUMERIC(14,3) NOT NULL DEFAULT 0, formula TEXT NOT NULL DEFAULT '',
 unit TEXT NOT NULL DEFAULT '', unit_price NUMERIC(16,2) NOT NULL, material_cost NUMERIC(16,2) NOT NULL DEFAULT 0,
 labor_cost NUMERIC(16,2) NOT NULL DEFAULT 0, total NUMERIC(16,2) NOT NULL
);
CREATE TABLE IF NOT EXISTS payments (
 id BIGSERIAL PRIMARY KEY, invoice_id BIGINT NOT NULL REFERENCES invoices(id), amount NUMERIC(16,2) NOT NULL CHECK(amount>0),
 method TEXT NOT NULL DEFAULT 'نقدي', paid_at DATE NOT NULL DEFAULT CURRENT_DATE, reference TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '',
 created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS paid_amount NUMERIC(16,2) NOT NULL DEFAULT 0;
ALTER TABLE invoices ADD COLUMN IF NOT EXISTS credited_amount NUMERIC(16,2) NOT NULL DEFAULT 0;
UPDATE invoices i SET paid_amount=COALESCE((SELECT sum(p.amount) FROM payments p WHERE p.invoice_id=i.id),0)
WHERE i.paid_amount=0 AND EXISTS (SELECT 1 FROM payments p WHERE p.invoice_id=i.id);
CREATE TABLE IF NOT EXISTS expenses (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT REFERENCES projects(id), category TEXT NOT NULL DEFAULT '', description TEXT NOT NULL,
 amount NUMERIC(16,2) NOT NULL CHECK(amount>=0), paid_at DATE NOT NULL DEFAULT CURRENT_DATE, payee TEXT NOT NULL DEFAULT '',
 reference TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS contractors (
 id BIGSERIAL PRIMARY KEY, name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', email TEXT NOT NULL DEFAULT '', specialty TEXT NOT NULL DEFAULT '',
 tax_number TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS employees (
 id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id), name TEXT NOT NULL, phone TEXT NOT NULL DEFAULT '', job_title TEXT NOT NULL DEFAULT '',
 hire_date DATE, salary NUMERIC(16,2) NOT NULL DEFAULT 0, active BOOLEAN NOT NULL DEFAULT TRUE, notes TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS labor_entries (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), employee_id BIGINT REFERENCES employees(id), contractor_id BIGINT REFERENCES contractors(id),
 work_date DATE NOT NULL DEFAULT CURRENT_DATE, description TEXT NOT NULL, hours NUMERIC(8,2) NOT NULL DEFAULT 0, amount NUMERIC(16,2) NOT NULL DEFAULT 0,
 created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS tasks (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT REFERENCES projects(id), title TEXT NOT NULL, description TEXT NOT NULL DEFAULT '',
 assigned_to BIGINT REFERENCES users(id), due_date DATE, status TEXT NOT NULL DEFAULT 'جديدة', priority TEXT NOT NULL DEFAULT 'عادية', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS daily_reports (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), report_date DATE NOT NULL DEFAULT CURRENT_DATE,
 weather TEXT NOT NULL DEFAULT '', workforce INTEGER NOT NULL DEFAULT 0, progress NUMERIC(5,2) NOT NULL DEFAULT 0, work_done TEXT NOT NULL DEFAULT '',
 blockers TEXT NOT NULL DEFAULT '', created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now(), UNIQUE(project_id,report_date)
);
CREATE TABLE IF NOT EXISTS accounts (
 id BIGSERIAL PRIMARY KEY, code TEXT NOT NULL UNIQUE, name TEXT NOT NULL, type TEXT NOT NULL CHECK(type IN ('asset','liability','equity','revenue','expense')),
 parent_id BIGINT REFERENCES accounts(id), active BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE TABLE IF NOT EXISTS journal_entries (
 id BIGSERIAL PRIMARY KEY, entry_no TEXT NOT NULL UNIQUE, entry_date DATE NOT NULL DEFAULT CURRENT_DATE, description TEXT NOT NULL,
 source_type TEXT NOT NULL DEFAULT '', source_id BIGINT, posted BOOLEAN NOT NULL DEFAULT FALSE, created_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS journal_lines (
 id BIGSERIAL PRIMARY KEY, journal_entry_id BIGINT NOT NULL REFERENCES journal_entries(id) ON DELETE CASCADE,
 account_id BIGINT NOT NULL REFERENCES accounts(id), debit NUMERIC(16,2) NOT NULL DEFAULT 0, credit NUMERIC(16,2) NOT NULL DEFAULT 0,
 project_id BIGINT REFERENCES projects(id), customer_id BIGINT REFERENCES customers(id), supplier_id BIGINT REFERENCES suppliers(id), memo TEXT NOT NULL DEFAULT '',
 CHECK(debit>=0 AND credit>=0 AND NOT (debit>0 AND credit>0))
);
CREATE TABLE IF NOT EXISTS system_settings (key TEXT PRIMARY KEY, value JSONB NOT NULL DEFAULT '{}'::jsonb, updated_by BIGINT REFERENCES users(id), updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS audit_log (
 id BIGSERIAL PRIMARY KEY, user_id BIGINT REFERENCES users(id), action TEXT NOT NULL, entity TEXT NOT NULL, entity_id BIGINT,
 details JSONB NOT NULL DEFAULT '{}'::jsonb, ip_address TEXT NOT NULL DEFAULT '', created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS site_visits (
 id BIGSERIAL PRIMARY KEY, customer_id BIGINT REFERENCES customers(id), project_id BIGINT REFERENCES projects(id), visit_date TIMESTAMPTZ NOT NULL DEFAULT now(),
 address TEXT NOT NULL DEFAULT '', attendees TEXT NOT NULL DEFAULT '', findings TEXT NOT NULL DEFAULT '', follow_up TEXT NOT NULL DEFAULT '', assigned_to BIGINT REFERENCES users(id), created_by BIGINT REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS measurements (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), boq_item_id BIGINT REFERENCES boq_items(id), room TEXT NOT NULL,
 label TEXT NOT NULL DEFAULT '', length NUMERIC(14,3) NOT NULL DEFAULT 0, width NUMERIC(14,3) NOT NULL DEFAULT 0, height NUMERIC(14,3) NOT NULL DEFAULT 0,
 count INTEGER NOT NULL DEFAULT 1, formula TEXT NOT NULL DEFAULT 'area', quantity NUMERIC(14,3) NOT NULL DEFAULT 0, measured_by BIGINT REFERENCES users(id), measured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS project_phases (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), name TEXT NOT NULL, sequence INTEGER NOT NULL DEFAULT 1,
 planned_start DATE, planned_end DATE, actual_start DATE, actual_end DATE, progress NUMERIC(5,2) NOT NULL DEFAULT 0, status TEXT NOT NULL DEFAULT 'لم تبدأ', notes TEXT NOT NULL DEFAULT ''
);
CREATE TABLE IF NOT EXISTS procurement_requests (
 id BIGSERIAL PRIMARY KEY, number TEXT NOT NULL UNIQUE, project_id BIGINT NOT NULL REFERENCES projects(id), requested_by BIGINT REFERENCES users(id),
 needed_by DATE, status TEXT NOT NULL DEFAULT 'جديد', notes TEXT NOT NULL DEFAULT '', approved_by BIGINT REFERENCES users(id), approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS procurement_request_items (
 id BIGSERIAL PRIMARY KEY, request_id BIGINT NOT NULL REFERENCES procurement_requests(id) ON DELETE CASCADE, material_id BIGINT REFERENCES materials(id),
 description TEXT NOT NULL, quantity NUMERIC(14,3) NOT NULL, unit TEXT NOT NULL DEFAULT '', estimated_price NUMERIC(16,2) NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS supplier_payments (
 id BIGSERIAL PRIMARY KEY, purchase_order_id BIGINT NOT NULL REFERENCES purchase_orders(id), amount NUMERIC(16,2) NOT NULL CHECK(amount>0),
 payment_date DATE NOT NULL DEFAULT CURRENT_DATE, method TEXT NOT NULL DEFAULT 'نقدي', reference TEXT NOT NULL DEFAULT '', notes TEXT NOT NULL DEFAULT '', created_by BIGINT REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS credit_notes (
 id BIGSERIAL PRIMARY KEY, number TEXT NOT NULL UNIQUE, invoice_id BIGINT NOT NULL REFERENCES invoices(id), amount NUMERIC(16,2) NOT NULL CHECK(amount>0),
 reason TEXT NOT NULL, status TEXT NOT NULL DEFAULT 'مسودة', issued_at DATE NOT NULL DEFAULT CURRENT_DATE, approved_by BIGINT REFERENCES users(id), approved_at TIMESTAMPTZ
);
UPDATE invoices i SET credited_amount=COALESCE((SELECT sum(cn.amount) FROM credit_notes cn WHERE cn.invoice_id=i.id AND cn.status='معتمد'),0)
WHERE i.credited_amount=0 AND EXISTS (SELECT 1 FROM credit_notes cn WHERE cn.invoice_id=i.id AND cn.status='معتمد');
CREATE TABLE IF NOT EXISTS contract_items (
 id BIGSERIAL PRIMARY KEY, contract_id BIGINT NOT NULL REFERENCES contracts(id) ON DELETE CASCADE, boq_item_id BIGINT REFERENCES boq_items(id),
 description TEXT NOT NULL, quantity NUMERIC(14,3) NOT NULL, unit TEXT NOT NULL DEFAULT '', unit_price NUMERIC(16,2) NOT NULL, total NUMERIC(16,2) NOT NULL
);
CREATE TABLE IF NOT EXISTS attachments (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT REFERENCES projects(id), customer_id BIGINT REFERENCES customers(id), entity_type TEXT NOT NULL,
 entity_id BIGINT NOT NULL, file_name TEXT NOT NULL, storage_url TEXT NOT NULL, mime_type TEXT NOT NULL DEFAULT '', file_size BIGINT NOT NULL DEFAULT 0,
 uploaded_by BIGINT REFERENCES users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS attendance (
 id BIGSERIAL PRIMARY KEY, employee_id BIGINT NOT NULL REFERENCES employees(id), work_date DATE NOT NULL DEFAULT CURRENT_DATE,
 check_in TIMESTAMPTZ, check_out TIMESTAMPTZ, status TEXT NOT NULL DEFAULT 'حاضر', notes TEXT NOT NULL DEFAULT '', UNIQUE(employee_id,work_date)
);
CREATE TABLE IF NOT EXISTS leave_requests (
 id BIGSERIAL PRIMARY KEY, employee_id BIGINT NOT NULL REFERENCES employees(id), start_date DATE NOT NULL, end_date DATE NOT NULL,
 leave_type TEXT NOT NULL DEFAULT 'سنوية', reason TEXT NOT NULL DEFAULT '', status TEXT NOT NULL DEFAULT 'بانتظار الاعتماد', approved_by BIGINT REFERENCES users(id), approved_at TIMESTAMPTZ
);
CREATE TABLE IF NOT EXISTS payroll_runs (
 id BIGSERIAL PRIMARY KEY, period_start DATE NOT NULL, period_end DATE NOT NULL, status TEXT NOT NULL DEFAULT 'مسودة', total NUMERIC(16,2) NOT NULL DEFAULT 0,
 approved_by BIGINT REFERENCES users(id), approved_at TIMESTAMPTZ, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS payroll_items (
 id BIGSERIAL PRIMARY KEY, payroll_run_id BIGINT NOT NULL REFERENCES payroll_runs(id) ON DELETE CASCADE, employee_id BIGINT NOT NULL REFERENCES employees(id),
 base_salary NUMERIC(16,2) NOT NULL DEFAULT 0, allowances NUMERIC(16,2) NOT NULL DEFAULT 0, deductions NUMERIC(16,2) NOT NULL DEFAULT 0,
 advances NUMERIC(16,2) NOT NULL DEFAULT 0, net NUMERIC(16,2) NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS handover_items (
 id BIGSERIAL PRIMARY KEY, project_id BIGINT NOT NULL REFERENCES projects(id), description TEXT NOT NULL, category TEXT NOT NULL DEFAULT '',
 status TEXT NOT NULL DEFAULT 'معلق', completed_at DATE, notes TEXT NOT NULL DEFAULT '', completed_by BIGINT REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS customer_contacts (
 id BIGSERIAL PRIMARY KEY, customer_id BIGINT NOT NULL REFERENCES customers(id), contact_date TIMESTAMPTZ NOT NULL DEFAULT now(), channel TEXT NOT NULL DEFAULT '',
 subject TEXT NOT NULL DEFAULT '', summary TEXT NOT NULL DEFAULT '', next_follow_up DATE, created_by BIGINT REFERENCES users(id)
);
CREATE INDEX IF NOT EXISTS idx_projects_customer ON projects(customer_id);
CREATE INDEX IF NOT EXISTS idx_boq_project ON boq_items(project_id);
CREATE INDEX IF NOT EXISTS idx_invoices_customer_date ON invoices(customer_id,issue_date);
CREATE INDEX IF NOT EXISTS idx_payments_invoice ON payments(invoice_id);
CREATE INDEX IF NOT EXISTS idx_expenses_project_date ON expenses(project_id,paid_at);
CREATE INDEX IF NOT EXISTS idx_stock_material_warehouse ON stock_movements(material_id,warehouse_id,created_at);
CREATE INDEX IF NOT EXISTS idx_tasks_assignee_status ON tasks(assigned_to,status);
CREATE INDEX IF NOT EXISTS idx_audit_entity ON audit_log(entity,entity_id,created_at);
CREATE INDEX IF NOT EXISTS idx_measurements_project ON measurements(project_id,room);
CREATE INDEX IF NOT EXISTS idx_phases_project ON project_phases(project_id,sequence);
CREATE INDEX IF NOT EXISTS idx_supplier_payments_order ON supplier_payments(purchase_order_id,payment_date);
INSERT INTO accounts(code,name,type) VALUES
 ('1000','الخزينة الرئيسية','asset'),('1010','الحسابات البنكية','asset'),('1100','العملاء - مدينون','asset'),('1200','المخزون','asset'),
 ('2000','الموردون - دائنون','liability'),('2100','ضرائب مستحقة','liability'),('3000','رأس المال','equity'),
 ('4000','إيرادات تنفيذ الأعمال','revenue'),('4100','إيرادات بيع الخامات','revenue'),
 ('5000','تكلفة الخامات','expense'),('5100','تكلفة المصنعية','expense'),('5200','تكلفة المقاولين','expense'),('6000','مصروفات تشغيلية','expense')
ON CONFLICT (code) DO NOTHING;
