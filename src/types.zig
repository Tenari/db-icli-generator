pub const Breed = struct {
    id: i64,
    name: []const u8,
    updated_at: []const u8,
    created_at: []const u8,
};

pub const AnimalGender = enum {
    male, female,
};

pub const Animal = struct {
    id: i64,
    gender: AnimalGender,
    breed_id: ?i64,
    father_id: ?i64,
    mother_id: ?i64,
    died_at: ?[]const u8,
    born_at: []const u8,
    updated_at: []const u8,
    created_at: []const u8,
};

pub const Weight = struct {
    id: i64,
    animal_id: i64,
    weight: f64,
    updated_at: []const u8,
    created_at: []const u8,
};
pub const Event = struct {
    id: i64,
    animal_id: i64,
    kind: EventKind,
    updated_at: []const u8,
    created_at: []const u8,
};

pub const EventKind = enum {
    birth,
    natural_death,
    slaughter,
    cull,
    purchase,
    sale,
    breed_attempt,
    pregnancy_test,
    kindling,
};

pub const Noun = enum {
    breed, animal, weight, event,

    pub fn toType(self: Noun) type {
        switch (self) {
            .breed => Breed,
            .animal => Animal,
            .weight => Weight,
            .event => Event,
        }
    }
};
