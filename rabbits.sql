CREATE TABLE IF NOT EXISTS breeds (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
);

CREATE TABLE IF NOT EXISTS animals (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  gender TEXT CHECK (gender IN ('m', 'f')),
  breed_id INTEGER,
  father_id INTEGER,
  mother_id INTEGER,
  born_at TEXT DEFAULT CURRENT_TIMESTAMP,
  died_at TEXT DEFAULT NULL,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (breed_id) REFERENCES breeds (id),
  FOREIGN KEY (father_id) REFERENCES animals (id),
  FOREIGN KEY (mother_id) REFERENCES animals (id)
);

CREATE TABLE IF NOT EXISTS weights (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  animal_id INTEGER NOT NULL,
  weight REAL NOT NULL,
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (animal_id) REFERENCES animals (id)
);

CREATE TABLE IF NOT EXISTS events (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  animal_id INTEGER NOT NULL,
  kind TEXT CHECK (kind IN ('birth', 'natural_death', 'slaughter', 'cull', 'purchase', 'sale', 'breed_attempt', 'pregnancy_test', 'kindling')),
  updated_at TEXT DEFAULT CURRENT_TIMESTAMP,
  created_at TEXT DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (animal_id) REFERENCES animals (id)
);
