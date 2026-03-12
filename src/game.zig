const std = @import("std");
const rl = @import("raylib");
const common = @import("common.zig");
const font = @import("font.zig");
const audio = @import("audio.zig");

pub const GameMode = enum {
    title,
    playing,
    game_over,
};

pub const AsteroidSize = enum(u8) {
    large,
    medium,
    small,
};

pub const BulletOwner = enum(u8) {
    player,
    saucer,
};

pub const SaucerSize = enum(u8) {
    large,
    small,
};

pub const ParticleKind = enum(u8) {
    shard,
    ember,
    flash,
};

pub const Rift = struct {
    active: bool = false,
    pos: common.Vec2 = common.zero(),
    vel: common.Vec2 = common.zero(),
    radius: f32 = 0.0,
    strength: f32 = 0.0,
    life: f32 = 0.0,
    max_life: f32 = 1.0,
    pulse: f32 = 0.0,
};

pub const Player = struct {
    pos: common.Vec2 = common.vec2(common.world_width * 0.5, common.world_height * 0.5),
    vel: common.Vec2 = common.zero(),
    angle: f32 = -common.pi / 2.0,
    alive: bool = false,
    invuln_timer: f32 = 0.0,
    respawn_timer: f32 = 0.0,
    fire_cooldown: f32 = 0.0,
    hyperspace_cooldown: f32 = 0.0,
    thrusting: bool = false,
    can_respawn: bool = false,
};

pub const Bullet = struct {
    active: bool = false,
    pos: common.Vec2 = common.zero(),
    vel: common.Vec2 = common.zero(),
    ttl: f32 = 0.0,
    owner: BulletOwner = .player,
};

pub const Asteroid = struct {
    active: bool = false,
    pos: common.Vec2 = common.zero(),
    vel: common.Vec2 = common.zero(),
    angle: f32 = 0.0,
    spin: f32 = 0.0,
    radius: f32 = 0.0,
    size: AsteroidSize = .large,
    point_count: usize = 0,
    shape: [12]common.Vec2 = [_]common.Vec2{common.zero()} ** 12,
};

pub const Saucer = struct {
    active: bool = false,
    pos: common.Vec2 = common.zero(),
    vel: common.Vec2 = common.zero(),
    size: SaucerSize = .large,
    shot_timer: f32 = 0.0,
    direction_timer: f32 = 0.0,
    hum_timer: f32 = 0.0,
};

pub const Particle = struct {
    active: bool = false,
    pos: common.Vec2 = common.zero(),
    vel: common.Vec2 = common.zero(),
    angle: f32 = 0.0,
    spin: f32 = 0.0,
    size: f32 = 1.0,
    life: f32 = 0.0,
    max_life: f32 = 1.0,
    intensity: f32 = 1.0,
    color: rl.Color = common.rgba(255, 255, 255, 255),
    kind: ParticleKind = .shard,
};

pub const Star = struct {
    pos: common.Vec2 = common.zero(),
    size: f32 = 1.0,
    phase: f32 = 0.0,
};

pub const Game = struct {
    rng: std.Random.DefaultPrng,
    mode: GameMode,
    player: Player,
    asteroids: [common.max_asteroids]Asteroid,
    bullets: [common.max_bullets]Bullet,
    particles: [common.max_particles]Particle,
    stars: [common.max_stars]Star,
    saucer: Saucer,
    rift: Rift,
    score: i32,
    high_score: i32,
    lives: i32,
    wave: i32,
    wave_message_timer: f32,
    wave_spawn_timer: f32,
    saucer_spawn_timer: f32,
    thrust_sound_timer: f32,
    heartbeat_timer: f32,
    heartbeat_high: bool,
    title_spin: f32,
    explosion_flash_intensity: f32,
    display_phase: f32,
    initial_wave_asteroids: i32,
    rift_spawn_timer: f32,

    pub fn init(seed: u64) Game {
        var game = Game{
            .rng = std.Random.DefaultPrng.init(seed),
            .mode = .title,
            .player = .{},
            .asteroids = std.mem.zeroes([common.max_asteroids]Asteroid),
            .bullets = std.mem.zeroes([common.max_bullets]Bullet),
            .particles = std.mem.zeroes([common.max_particles]Particle),
            .stars = std.mem.zeroes([common.max_stars]Star),
            .saucer = .{},
            .rift = .{},
            .score = 0,
            .high_score = 0,
            .lives = 3,
            .wave = 1,
            .wave_message_timer = 0.0,
            .wave_spawn_timer = 0.0,
            .saucer_spawn_timer = 12.0,
            .thrust_sound_timer = 0.0,
            .heartbeat_timer = 0.7,
            .heartbeat_high = false,
            .title_spin = 0.0,
            .explosion_flash_intensity = 0.0,
            .display_phase = 0.0,
            .initial_wave_asteroids = 4,
            .rift_spawn_timer = 8.0,
        };
        game.seedStars();
        game.seedTitleField();
        return game;
    }

    pub fn update(self: *Game, dt: f32, bank: *audio.AudioBank) void {
        self.display_phase += dt;
        self.title_spin += dt * 0.35;
        self.explosion_flash_intensity = common.approach(self.explosion_flash_intensity, 0.0, dt * 1.8);
        self.updateParticles(dt);

        switch (self.mode) {
            .title => {
                self.updateTitle();
                if (rl.isKeyPressed(.enter)) {
                    self.startGame();
                    audio.playExtraLife(bank, 0.18, 1.0);
                }
            },
            .playing => self.updatePlaying(dt, bank),
            .game_over => {
                self.updatePlayingWorld(dt, false);
                self.updateSaucer(dt, bank);
                self.updateBullets(dt);
                if (rl.isKeyPressed(.enter)) self.startGame();
            },
        }
    }

    fn startGame(self: *Game) void {
        self.mode = .playing;
        self.score = 0;
        self.lives = 3;
        self.wave = 1;
        self.wave_message_timer = 2.2;
        self.wave_spawn_timer = 0.0;
        self.saucer_spawn_timer = self.nextSaucerDelay();
        self.thrust_sound_timer = 0.0;
        self.heartbeat_timer = 0.8;
        self.heartbeat_high = false;
        self.explosion_flash_intensity = 0.0;
        self.rift = .{};
        self.rift_spawn_timer = self.nextRiftDelay();
        self.player = .{};
        self.player.alive = true;
        self.player.invuln_timer = 2.5;
        self.player.pos = common.vec2(common.world_width * 0.5, common.world_height * 0.5);
        self.clearActors();
        self.spawnWave();
    }

    fn seedTitleField(self: *Game) void {
        self.mode = .title;
        self.clearActors();
        self.player = .{};
        self.wave = 1;
        self.score = 0;
        self.wave_message_timer = 0.0;
        self.saucer_spawn_timer = 99.0;
        self.rift = .{};
        self.rift_spawn_timer = 99.0;
        for (0..7) |_| {
            const pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height));
            const angle = self.randRange(0.0, common.tau);
            const speed = self.randRange(18.0, 42.0);
            _ = self.spawnAsteroid(.large, pos, common.fromAngle(angle, speed));
        }
        for (0..160) |_| {
            const life = self.randRange(0.5, 3.0);
            self.spawnParticle(.{
                .pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height)),
                .vel = common.zero(),
                .angle = self.randRange(0.0, common.tau),
                .spin = self.randRange(-0.8, 0.8),
                .size = self.randRange(1.0, 2.4),
                .life = life,
                .max_life = life,
                .intensity = self.randRange(0.18, 0.35),
                .color = common.rgba(110, 160, 255, 255),
                .kind = .ember,
            });
        }
    }

    fn clearActors(self: *Game) void {
        self.asteroids = std.mem.zeroes([common.max_asteroids]Asteroid);
        self.bullets = std.mem.zeroes([common.max_bullets]Bullet);
        self.particles = std.mem.zeroes([common.max_particles]Particle);
        self.saucer = .{};
        self.rift = .{};
    }

    fn seedStars(self: *Game) void {
        for (&self.stars) |*star| {
            star.* = .{
                .pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height)),
                .size = self.randRange(0.7, 2.2),
                .phase = self.randRange(0.0, common.tau),
            };
        }
    }

    fn updateTitle(self: *Game) void {
        self.updateAsteroids(common.fixed_dt);
        for (&self.particles) |*particle| {
            if (!particle.active) {
                const life = self.randRange(0.8, 3.2);
                particle.* = .{
                    .active = true,
                    .pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height)),
                    .vel = common.zero(),
                    .angle = self.randRange(0.0, common.tau),
                    .spin = self.randRange(-0.8, 0.8),
                    .size = self.randRange(1.0, 2.4),
                    .life = life,
                    .max_life = life,
                    .intensity = self.randRange(0.18, 0.35),
                    .color = common.rgba(110, 160, 255, 255),
                    .kind = .ember,
                };
            }
        }
        if (self.countActiveAsteroids() < 5) {
            const pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height));
            const angle = self.randRange(0.0, common.tau);
            const speed = self.randRange(20.0, 50.0);
            _ = self.spawnAsteroid(.large, pos, common.fromAngle(angle, speed));
        }
    }

    fn updatePlaying(self: *Game, dt: f32, bank: *audio.AudioBank) void {
        self.updatePlayingWorld(dt, true);
        self.updatePlayer(dt, bank);
        self.updateSaucer(dt, bank);
        self.updateBullets(dt);
        self.updateCollisions(bank);
        self.handleWaveProgress(bank, dt);
        self.handleRespawn(dt);
        self.handleHeartbeat(bank, dt);
        if (self.score > self.high_score) self.high_score = self.score;
    }

    fn updatePlayingWorld(self: *Game, dt: f32, allow_saucer_spawn: bool) void {
        self.wave_message_timer = @max(self.wave_message_timer - dt, 0.0);
        self.updateRift(dt, allow_saucer_spawn);
        self.updateAsteroids(dt);
        if (allow_saucer_spawn and !self.saucer.active) {
            self.saucer_spawn_timer -= dt;
            if (self.saucer_spawn_timer <= 0.0) {
                self.spawnSaucer();
                self.saucer_spawn_timer = self.nextSaucerDelay();
            }
        }
    }

    fn updatePlayer(self: *Game, dt: f32, bank: *audio.AudioBank) void {
        self.player.fire_cooldown = @max(self.player.fire_cooldown - dt, 0.0);
        self.player.hyperspace_cooldown = @max(self.player.hyperspace_cooldown - dt, 0.0);
        self.player.invuln_timer = @max(self.player.invuln_timer - dt, 0.0);
        self.thrust_sound_timer = @max(self.thrust_sound_timer - dt, 0.0);
        if (!self.player.alive) return;

        const rotate_left = rl.isKeyDown(.left) or rl.isKeyDown(.a);
        const rotate_right = rl.isKeyDown(.right) or rl.isKeyDown(.d);
        const thrust = rl.isKeyDown(.up) or rl.isKeyDown(.w);
        const fire = rl.isKeyDown(.space);
        const hyperspace = rl.isKeyPressed(.left_shift) or rl.isKeyPressed(.right_shift);

        if (rotate_left) self.player.angle -= 4.3 * dt;
        if (rotate_right) self.player.angle += 4.3 * dt;

        self.player.thrusting = thrust;
        if (thrust) {
            self.player.vel = common.add(self.player.vel, common.fromAngle(self.player.angle, 380.0 * dt));
            self.spawnThrustParticles();
            if (self.thrust_sound_timer <= 0.0) {
                audio.playThrust(bank, 0.20, self.randRange(0.92, 1.08));
                self.thrust_sound_timer = 0.065;
            }
        }
        self.player.vel = common.add(self.player.vel, common.scale(self.riftAcceleration(self.player.pos, 1.0), dt));
        self.player.vel = common.scale(self.player.vel, 0.999);
        self.player.pos = common.wrapPoint(common.add(self.player.pos, common.scale(self.player.vel, dt)));

        if (fire and self.player.fire_cooldown <= 0.0 and self.countBullets(.player) < common.max_player_bullets) {
            self.firePlayerBullet(bank);
        }
        if (hyperspace and self.player.hyperspace_cooldown <= 0.0) {
            self.useHyperspace(bank);
        }
    }

    fn updateAsteroids(self: *Game, dt: f32) void {
        for (&self.asteroids) |*asteroid| {
            if (!asteroid.active) continue;
            asteroid.vel = common.add(asteroid.vel, common.scale(self.riftAcceleration(asteroid.pos, 0.52), dt));
            asteroid.pos = common.wrapPoint(common.add(asteroid.pos, common.scale(asteroid.vel, dt)));
            asteroid.angle += asteroid.spin * dt;
        }
    }

    fn updateBullets(self: *Game, dt: f32) void {
        for (&self.bullets) |*bullet| {
            if (!bullet.active) continue;
            bullet.ttl -= dt;
            if (bullet.ttl <= 0.0) {
                bullet.active = false;
                continue;
            }
            bullet.vel = common.add(bullet.vel, common.scale(self.riftAcceleration(bullet.pos, 0.32), dt));
            bullet.pos = common.wrapPoint(common.add(bullet.pos, common.scale(bullet.vel, dt)));
            if (self.rift.active and common.torusDistanceSq(bullet.pos, self.rift.pos) < common.sqr(self.rift.radius * 0.24)) {
                bullet.active = false;
                self.spawnRadialBurst(bullet.pos, if (bullet.owner == .player) common.rgba(180, 235, 255, 255) else common.rgba(255, 120, 210, 255), 6, 90.0);
            }
        }
    }

    fn updateSaucer(self: *Game, dt: f32, bank: *audio.AudioBank) void {
        if (!self.saucer.active) return;
        self.saucer.shot_timer -= dt;
        self.saucer.direction_timer -= dt;
        self.saucer.hum_timer -= dt;

        if (self.saucer.hum_timer <= 0.0) {
            audio.playSaucerHum(bank, if (self.saucer.size == .large) 0.16 else 0.20, if (self.saucer.size == .large) 0.8 else 1.3);
            self.saucer.hum_timer = 0.26;
        }

        if (self.saucer.direction_timer <= 0.0) {
            self.saucer.direction_timer = self.randRange(1.3, 2.6);
            self.saucer.vel.y = self.randRange(-70.0, 70.0);
        }

        self.saucer.pos = common.add(self.saucer.pos, common.scale(self.saucer.vel, dt));
        self.saucer.vel = common.add(self.saucer.vel, common.scale(self.riftAcceleration(self.saucer.pos, 0.38), dt));
        if (self.saucer.pos.y < 90.0 or self.saucer.pos.y > common.world_height - 90.0) self.saucer.vel.y *= -1.0;
        if ((self.saucer.vel.x > 0.0 and self.saucer.pos.x > common.world_width + 120.0) or
            (self.saucer.vel.x < 0.0 and self.saucer.pos.x < -120.0))
        {
            self.saucer.active = false;
            return;
        }

        if (self.saucer.shot_timer <= 0.0) {
            self.fireSaucerBullet(bank);
            self.saucer.shot_timer = if (self.saucer.size == .large) self.randRange(1.1, 1.8) else self.randRange(0.7, 1.1);
        }
    }

    fn updateParticles(self: *Game, dt: f32) void {
        for (&self.particles) |*particle| {
            if (!particle.active) continue;
            particle.life -= dt;
            if (particle.life <= 0.0) {
                particle.active = false;
                continue;
            }
            particle.pos = common.wrapPoint(common.add(particle.pos, common.scale(particle.vel, dt)));
            particle.angle += particle.spin * dt;
            particle.vel = common.scale(particle.vel, 1.0 - dt * 0.35);
        }
    }

    fn updateRift(self: *Game, dt: f32, allow_spawn: bool) void {
        if (self.rift.active) {
            self.rift.life -= dt;
            self.rift.pulse += dt * 2.2;
            self.rift.pos = common.wrapPoint(common.add(self.rift.pos, common.scale(self.rift.vel, dt)));
            if (self.rift.life <= 0.0) {
                self.spawnRadialBurst(self.rift.pos, common.rgba(120, 200, 255, 255), 22, 160.0);
                self.rift = .{};
                self.rift_spawn_timer = self.nextRiftDelay();
            } else if (self.randRange(0.0, 1.0) < dt * 18.0) {
                const angle = self.randRange(0.0, common.tau);
                const rim = self.rift.radius * self.randRange(0.4, 0.95);
                const life = self.randRange(0.18, 0.45);
                self.spawnParticle(.{
                    .pos = common.wrapPoint(common.add(self.rift.pos, common.fromAngle(angle, rim))),
                    .vel = common.fromAngle(angle + common.pi * 0.5, self.randRange(10.0, 35.0)),
                    .angle = angle,
                    .spin = self.randRange(-8.0, 8.0),
                    .size = self.randRange(3.0, 6.5),
                    .life = life,
                    .max_life = life,
                    .intensity = self.randRange(0.25, 0.55),
                    .color = common.rgba(120, 180, 255, 255),
                    .kind = .flash,
                });
            }
            return;
        }

        if (!allow_spawn or self.mode != .playing or self.wave < 2) return;
        self.rift_spawn_timer -= dt;
        if (self.rift_spawn_timer > 0.0) return;
        self.spawnRift();
    }

    fn updateCollisions(self: *Game, bank: *audio.AudioBank) void {
        self.consumeRiftVictims(bank);

        for (&self.bullets) |*bullet| {
            if (!bullet.active) continue;

            if (bullet.owner == .player and self.saucer.active) {
                const saucer_radius: f32 = if (self.saucer.size == .large) 26.0 else 18.0;
                if (common.torusDistanceSq(bullet.pos, self.saucer.pos) < common.sqr(saucer_radius)) {
                    bullet.active = false;
                    self.destroySaucer(bank);
                    continue;
                }
            }

            for (0..self.asteroids.len) |i| {
                if (!self.asteroids[i].active) continue;
                if (common.torusDistanceSq(bullet.pos, self.asteroids[i].pos) < common.sqr(self.asteroids[i].radius + 3.0)) {
                    bullet.active = false;
                    self.destroyAsteroid(i, bullet.pos, bank);
                    break;
                }
            }
        }

        if (self.player.alive and self.player.invuln_timer <= 0.0) {
            if (self.rift.active and common.torusDistanceSq(self.player.pos, self.rift.pos) < common.sqr(self.rift.radius * 0.24)) {
                self.killPlayer(bank);
                return;
            }

            for (&self.asteroids) |*asteroid| {
                if (!asteroid.active) continue;
                if (common.torusDistanceSq(self.player.pos, asteroid.pos) < common.sqr(asteroid.radius + 14.0)) {
                    self.killPlayer(bank);
                    break;
                }
            }

            if (self.player.alive and self.saucer.active) {
                const saucer_radius: f32 = if (self.saucer.size == .large) 26.0 else 18.0;
                if (common.torusDistanceSq(self.player.pos, self.saucer.pos) < common.sqr(saucer_radius + 14.0)) self.killPlayer(bank);
            }

            if (self.player.alive) {
                for (&self.bullets) |*bullet| {
                    if (!bullet.active or bullet.owner != .saucer) continue;
                    if (common.torusDistanceSq(self.player.pos, bullet.pos) < common.sqr(14.0)) {
                        bullet.active = false;
                        self.killPlayer(bank);
                        break;
                    }
                }
            }
        }
    }

    fn handleWaveProgress(self: *Game, bank: *audio.AudioBank, dt: f32) void {
        if (self.countActiveAsteroids() == 0 and !self.saucer.active) {
            self.wave_spawn_timer -= dt;
            if (self.wave_spawn_timer <= 0.0) {
                self.wave += 1;
                self.wave_message_timer = 2.0;
                self.wave_spawn_timer = 0.0;
                self.spawnWave();
                audio.playExtraLife(bank, 0.12, 0.7);
            }
        } else {
            self.wave_spawn_timer = 1.6;
        }
    }

    fn handleRespawn(self: *Game, dt: f32) void {
        if (self.player.alive or self.mode != .playing) return;
        self.player.respawn_timer -= dt;
        if (self.player.respawn_timer > 0.0) return;

        if (!self.player.can_respawn) {
            self.mode = .game_over;
            return;
        }

        if (self.isSpawnSafe()) {
            self.player.alive = true;
            self.player.can_respawn = false;
            self.player.pos = common.vec2(common.world_width * 0.5, common.world_height * 0.5);
            self.player.vel = common.zero();
            self.player.angle = -common.pi / 2.0;
            self.player.invuln_timer = 2.2;
        }
    }

    fn handleHeartbeat(self: *Game, bank: *audio.AudioBank, dt: f32) void {
        if (self.mode != .playing) return;
        const remaining = self.countActiveAsteroids();
        if (remaining == 0) return;
        self.heartbeat_timer -= dt;
        if (self.heartbeat_timer > 0.0) return;

        const progress = 1.0 - (@as(f32, @floatFromInt(remaining)) / @max(@as(f32, @floatFromInt(self.initial_wave_asteroids)), 1.0));
        self.heartbeat_timer = common.lerp(1.0, 0.26, progress);
        self.heartbeat_high = !self.heartbeat_high;
        if (self.heartbeat_high) audio.playBeatHigh(bank, 0.16, 1.0) else audio.playBeatLow(bank, 0.16, 1.0);
    }

    fn firePlayerBullet(self: *Game, bank: *audio.AudioBank) void {
        const dir = common.fromAngle(self.player.angle, 1.0);
        const spawn_pos = common.wrapPoint(common.add(self.player.pos, common.scale(dir, 18.0)));
        const velocity = common.add(self.player.vel, common.scale(dir, 620.0));

        for (&self.bullets) |*bullet| {
            if (bullet.active) continue;
            bullet.* = .{ .active = true, .pos = spawn_pos, .vel = velocity, .ttl = 1.15, .owner = .player };
            self.player.fire_cooldown = 0.18;
            self.emitShotFlash(spawn_pos, dir, common.rgba(210, 240, 255, 255));
            audio.playShoot(bank, 0.24, self.randRange(0.94, 1.08));
            return;
        }
    }

    fn fireSaucerBullet(self: *Game, bank: *audio.AudioBank) void {
        if (!self.saucer.active) return;
        const aim_pos = if (self.player.alive) self.player.pos else common.vec2(common.world_width * 0.5, common.world_height * 0.5);
        var delta = common.torusDelta(self.saucer.pos, aim_pos);
        delta = common.rotate(delta, if (self.saucer.size == .large) self.randRange(-0.65, 0.65) else self.randRange(-0.18, 0.18));
        const velocity = common.normalizeOr(delta, common.vec2(1.0, 0.0), if (self.saucer.size == .large) 420.0 else 500.0);

        for (&self.bullets) |*bullet| {
            if (bullet.active) continue;
            bullet.* = .{ .active = true, .pos = common.wrapPoint(self.saucer.pos), .vel = velocity, .ttl = 1.6, .owner = .saucer };
            self.emitShotFlash(self.saucer.pos, common.normalizeOr(delta, common.vec2(1.0, 0.0), 1.0), common.rgba(255, 100, 180, 255));
            audio.playSaucerFire(bank, 0.22, if (self.saucer.size == .large) 0.94 else 1.16);
            return;
        }
    }

    fn useHyperspace(self: *Game, bank: *audio.AudioBank) void {
        self.player.hyperspace_cooldown = 2.0;
        self.spawnRadialBurst(self.player.pos, common.rgba(170, 180, 255, 255), 18, 160.0);
        self.player.pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height));
        self.player.vel = common.scale(self.player.vel, 0.15);
        self.player.invuln_timer = 0.8;
        audio.playHyperspace(bank, 0.24, self.randRange(0.9, 1.1));
        if (self.randRange(0.0, 1.0) < 0.08 and self.countActiveAsteroids() > 2) self.killPlayer(bank);
    }

    fn killPlayer(self: *Game, bank: *audio.AudioBank) void {
        if (!self.player.alive) return;
        self.player.alive = false;
        self.player.thrusting = false;
        self.player.respawn_timer = 2.1;
        self.player.vel = common.zero();
        self.spawnShipExplosion(self.player.pos);
        self.explosion_flash_intensity = 0.55;
        audio.playDeath(bank, 0.32, 1.0);
        if (self.lives > 0) {
            self.lives -= 1;
            self.player.can_respawn = true;
        } else {
            self.player.can_respawn = false;
        }
    }

    fn destroySaucer(self: *Game, bank: *audio.AudioBank) void {
        const points: i32 = if (self.saucer.size == .large) 200 else 1000;
        self.awardScore(points, bank);
        self.spawnRadialBurst(self.saucer.pos, common.rgba(255, 140, 220, 255), if (self.saucer.size == .large) 26 else 22, 180.0);
        self.saucer.active = false;
        self.explosion_flash_intensity = @max(self.explosion_flash_intensity, 0.25);
        audio.playBangMedium(bank, 0.25, if (self.saucer.size == .large) 0.8 else 1.2);
    }

    fn destroyAsteroid(self: *Game, index: usize, impact_pos: common.Vec2, bank: *audio.AudioBank) void {
        const asteroid = self.asteroids[index];
        self.asteroids[index].active = false;
        const points: i32 = switch (asteroid.size) {
            .large => 20,
            .medium => 50,
            .small => 100,
        };
        self.awardScore(points, bank);

        const burst_color = switch (asteroid.size) {
            .large => common.rgba(205, 228, 255, 255),
            .medium => common.rgba(255, 210, 120, 255),
            .small => common.rgba(255, 130, 90, 255),
        };
        const burst_speed: f32 = switch (asteroid.size) {
            .large => 150.0,
            .medium => 180.0,
            .small => 220.0,
        };
        const burst_count: usize = switch (asteroid.size) {
            .large => 20,
            .medium => 14,
            .small => 10,
        };
        self.spawnRadialBurst(impact_pos, burst_color, burst_count, burst_speed);
        self.explosion_flash_intensity = @max(self.explosion_flash_intensity, 0.12);
        switch (asteroid.size) {
            .large => audio.playBangLarge(bank, 0.26, self.randRange(0.9, 1.06)),
            .medium => audio.playBangMedium(bank, 0.22, self.randRange(0.98, 1.12)),
            .small => audio.playBangSmall(bank, 0.20, self.randRange(1.0, 1.18)),
        }
        if (asteroid.size == .small) return;

        const child_size: AsteroidSize = if (asteroid.size == .large) .medium else .small;
        const base_dir = common.normalizeOr(asteroid.vel, common.fromAngle(self.randRange(0.0, common.tau), 1.0), 1.0);
        const side_a = common.rotate(base_dir, self.randRange(0.65, 1.15));
        const side_b = common.rotate(base_dir, -self.randRange(0.65, 1.15));
        const child_speed = if (child_size == .medium) self.randRange(90.0, 135.0) else self.randRange(140.0, 210.0);
        _ = self.spawnAsteroid(child_size, impact_pos, common.add(common.scale(side_a, child_speed), common.scale(asteroid.vel, 0.15)));
        _ = self.spawnAsteroid(child_size, impact_pos, common.add(common.scale(side_b, child_speed), common.scale(asteroid.vel, 0.15)));
    }

    fn consumeRiftVictims(self: *Game, bank: *audio.AudioBank) void {
        if (!self.rift.active) return;
        const core_radius = self.rift.radius * 0.24;
        const core_radius_sq = common.sqr(core_radius);

        for (0..self.asteroids.len) |i| {
            if (!self.asteroids[i].active) continue;
            if (common.torusDistanceSq(self.asteroids[i].pos, self.rift.pos) >= core_radius_sq) continue;

            const asteroid = self.asteroids[i];
            self.asteroids[i].active = false;
            self.awardScore(switch (asteroid.size) {
                .large => 40,
                .medium => 80,
                .small => 140,
            }, bank);
            self.spawnRadialBurst(asteroid.pos, common.rgba(120, 210, 255, 255), switch (asteroid.size) {
                .large => 18,
                .medium => 12,
                .small => 8,
            }, 140.0);
            self.explosion_flash_intensity = @max(self.explosion_flash_intensity, 0.08);
        }

        if (self.saucer.active and common.torusDistanceSq(self.saucer.pos, self.rift.pos) < common.sqr(core_radius + 10.0)) {
            self.awardScore(if (self.saucer.size == .large) 300 else 1200, bank);
            self.spawnRadialBurst(self.saucer.pos, common.rgba(255, 140, 220, 255), if (self.saucer.size == .large) 20 else 24, 165.0);
            self.saucer.active = false;
            self.explosion_flash_intensity = @max(self.explosion_flash_intensity, 0.18);
            audio.playBangMedium(bank, 0.24, 1.15);
        }
    }

    fn spawnWave(self: *Game) void {
        self.saucer.active = false;
        self.initial_wave_asteroids = @min(4 + self.wave, 11);
        for (0..@as(usize, @intCast(self.initial_wave_asteroids))) |_| {
            var pos = common.zero();
            while (true) {
                pos = common.vec2(self.randRange(0.0, common.world_width), self.randRange(0.0, common.world_height));
                if (common.torusDistanceSq(pos, common.vec2(common.world_width * 0.5, common.world_height * 0.5)) > common.sqr(240.0)) break;
            }
            const speed = self.randRange(34.0, 78.0) + @as(f32, @floatFromInt(self.wave - 1)) * 4.0;
            _ = self.spawnAsteroid(.large, pos, common.fromAngle(self.randRange(0.0, common.tau), speed));
        }
    }

    fn spawnSaucer(self: *Game) void {
        self.saucer.active = true;
        self.saucer.size = if (self.wave < 3 or self.randRange(0.0, 1.0) < 0.55) .large else .small;
        const from_left = self.randRange(0.0, 1.0) < 0.5;
        self.saucer.pos = common.vec2(if (from_left) -60.0 else common.world_width + 60.0, self.randRange(120.0, common.world_height - 120.0));
        self.saucer.vel = common.vec2(if (from_left) self.randRange(90.0, 130.0) else -self.randRange(90.0, 130.0), self.randRange(-55.0, 55.0));
        self.saucer.shot_timer = self.randRange(0.8, 1.4);
        self.saucer.direction_timer = self.randRange(1.0, 2.0);
        self.saucer.hum_timer = 0.05;
    }

    fn spawnRift(self: *Game) void {
        var pos = common.zero();
        const avoid_pos = if (self.player.alive) self.player.pos else common.vec2(common.world_width * 0.5, common.world_height * 0.5);
        while (true) {
            pos = common.vec2(self.randRange(180.0, common.world_width - 180.0), self.randRange(140.0, common.world_height - 140.0));
            if (common.torusDistanceSq(pos, avoid_pos) > common.sqr(220.0)) break;
        }
        self.rift = .{
            .active = true,
            .pos = pos,
            .vel = common.fromAngle(self.randRange(0.0, common.tau), self.randRange(8.0, 20.0)),
            .radius = self.randRange(88.0, 118.0),
            .strength = self.randRange(28_000.0, 36_000.0),
            .life = self.randRange(7.0, 11.0),
            .max_life = 11.0,
            .pulse = self.randRange(0.0, common.tau),
        };
        self.rift.max_life = self.rift.life;
        self.spawnRadialBurst(self.rift.pos, common.rgba(120, 200, 255, 255), 18, 120.0);
    }

    fn spawnAsteroid(self: *Game, size: AsteroidSize, pos: common.Vec2, vel: common.Vec2) bool {
        for (&self.asteroids) |*asteroid| {
            if (asteroid.active) continue;
            const radius: f32 = switch (size) {
                .large => 52.0,
                .medium => 30.0,
                .small => 18.0,
            };
            const point_count: usize = switch (size) {
                .large => 10,
                .medium => 9,
                .small => 8,
            };
            asteroid.* = .{ .active = true, .pos = common.wrapPoint(pos), .vel = vel, .angle = self.randRange(0.0, common.tau), .spin = self.randRange(-1.2, 1.2), .radius = radius, .size = size, .point_count = point_count };
            asteroid.shape = [_]common.Vec2{common.zero()} ** 12;
            for (0..point_count) |i| {
                const angle = common.tau * (@as(f32, @floatFromInt(i)) / @as(f32, @floatFromInt(point_count)));
                asteroid.shape[i] = common.vec2(@cos(angle) * radius * self.randRange(0.72, 1.18), @sin(angle) * radius * self.randRange(0.72, 1.18));
            }
            return true;
        }
        return false;
    }

    fn spawnParticle(self: *Game, particle: Particle) void {
        for (&self.particles) |*slot| {
            if (slot.active) continue;
            slot.* = particle;
            slot.active = true;
            return;
        }
    }

    fn spawnRadialBurst(self: *Game, pos: common.Vec2, color: rl.Color, count: usize, speed: f32) void {
        for (0..count) |_| {
            const angle = self.randRange(0.0, common.tau);
            const lifetime = self.randRange(0.25, 0.75);
            self.spawnParticle(.{
                .pos = pos,
                .vel = common.fromAngle(angle, self.randRange(speed * 0.35, speed)),
                .angle = angle,
                .spin = self.randRange(-8.0, 8.0),
                .size = self.randRange(3.0, 10.0),
                .life = lifetime,
                .max_life = lifetime,
                .intensity = self.randRange(0.45, 0.95),
                .color = color,
                .kind = if (self.randRange(0.0, 1.0) < 0.25) .flash else .shard,
            });
        }
    }

    fn spawnShipExplosion(self: *Game, pos: common.Vec2) void {
        self.spawnRadialBurst(pos, common.rgba(240, 250, 255, 255), 28, 240.0);
        self.spawnRadialBurst(pos, common.rgba(255, 140, 110, 255), 14, 180.0);
    }

    fn spawnThrustParticles(self: *Game) void {
        const back = common.fromAngle(self.player.angle + common.pi, 1.0);
        const pos = common.wrapPoint(common.add(common.add(self.player.pos, common.scale(back, 16.0)), common.fromAngle(self.player.angle + common.pi / 2.0, self.randRange(-6.0, 6.0))));
        const life = self.randRange(0.18, 0.36);
        self.spawnParticle(.{ .pos = pos, .vel = common.add(common.scale(back, self.randRange(110.0, 180.0)), common.scale(self.player.vel, 0.15)), .angle = self.player.angle + common.pi, .spin = self.randRange(-10.0, 10.0), .size = self.randRange(4.0, 9.0), .life = life, .max_life = life, .intensity = self.randRange(0.45, 0.85), .color = common.rgba(255, 168, 100, 255), .kind = .shard });
    }

    fn emitShotFlash(self: *Game, pos: common.Vec2, dir: common.Vec2, color: rl.Color) void {
        self.spawnParticle(.{ .pos = pos, .vel = common.scale(dir, 70.0), .angle = std.math.atan2(dir.y, dir.x), .spin = self.randRange(-14.0, 14.0), .size = 7.0, .life = 0.12, .max_life = 0.12, .intensity = 0.9, .color = color, .kind = .flash });
    }

    fn isSpawnSafe(self: *Game) bool {
        const center = common.vec2(common.world_width * 0.5, common.world_height * 0.5);
        for (&self.asteroids) |*asteroid| {
            if (asteroid.active and common.torusDistanceSq(center, asteroid.pos) < common.sqr(140.0 + asteroid.radius)) return false;
        }
        if (self.saucer.active and common.torusDistanceSq(center, self.saucer.pos) < common.sqr(180.0)) return false;
        return true;
    }

    fn nextSaucerDelay(self: *Game) f32 {
        return self.randRange(11.0, 19.0);
    }

    fn nextRiftDelay(self: *Game) f32 {
        return self.randRange(12.0, 20.0);
    }

    fn riftAcceleration(self: *const Game, pos: common.Vec2, intensity: f32) common.Vec2 {
        if (!self.rift.active) return common.zero();
        const delta = common.torusDelta(pos, self.rift.pos);
        const dist_sq = @max(common.lengthSq(delta), 144.0);
        const dist = @sqrt(dist_sq);
        if (dist > self.rift.radius * 2.9) return common.zero();

        const falloff = std.math.clamp(1.0 - dist / (self.rift.radius * 2.9), 0.0, 1.0);
        const swirl = common.rotate(common.normalizeOr(delta, common.vec2(1.0, 0.0), 1.0), common.pi / 2.0);
        const pull = common.normalizeOr(delta, common.vec2(1.0, 0.0), (self.rift.strength / dist_sq) * (0.55 + falloff * 0.9) * intensity);
        return common.add(pull, common.scale(swirl, 42.0 * (0.35 + falloff) * intensity));
    }

    fn awardScore(self: *Game, points: i32, bank: *audio.AudioBank) void {
        const old_score = self.score;
        self.score += points;
        if (@divTrunc(self.score, 10_000) > @divTrunc(old_score, 10_000)) {
            self.lives += 1;
            audio.playExtraLife(bank, 0.24, 1.0);
        }
    }

    fn countActiveAsteroids(self: *Game) i32 {
        var total: i32 = 0;
        for (&self.asteroids) |*asteroid| {
            if (asteroid.active) total += 1;
        }
        return total;
    }

    fn countBullets(self: *Game, owner: BulletOwner) i32 {
        var total: i32 = 0;
        for (&self.bullets) |*bullet| {
            if (bullet.active and bullet.owner == owner) total += 1;
        }
        return total;
    }

    fn randRange(self: *Game, min: f32, max: f32) f32 {
        return min + self.rng.random().float(f32) * (max - min);
    }

    pub fn drawWorld(self: *const Game) void {
        drawBackground(self);
        rl.beginBlendMode(.additive);
        defer rl.endBlendMode();
        drawStars(self);
        if (self.rift.active) drawRift(self.rift, self.display_phase);
        for (self.particles) |particle| if (particle.active) drawParticle(particle);
        for (self.bullets) |bullet| if (bullet.active) drawBullet(bullet);
        for (self.asteroids) |asteroid| if (asteroid.active) drawAsteroid(asteroid);
        if (self.saucer.active) drawSaucer(self.saucer);
        if (self.player.alive and (self.player.invuln_timer <= 0.0 or @mod(self.display_phase * 12.0, 2.0) < 1.0)) drawShip(self.player);
    }

    pub fn drawOverlay(self: *const Game, render_w: f32, render_h: f32) void {
        drawHud(self, render_w, render_h);
        switch (self.mode) {
            .title => drawTitle(self, render_w, render_h),
            .playing => drawWaveMessage(self, render_w, render_h),
            .game_over => drawGameOver(self, render_w, render_h),
        }
    }
};

fn drawRift(rift: Rift, display_phase: f32) void {
    const envelope = std.math.clamp(@min(rift.life, rift.max_life - rift.life) / 1.2 + 0.25, 0.0, 1.0);
    const shell_color = common.rgba(110, 190, 255, 255);
    const core_color = common.rgba(220, 245, 255, 255);
    const radius = rift.radius * (0.92 + 0.08 * @sin(rift.pulse));
    const x_offsets = common.wrapOffsets(rift.pos.x, radius + 24.0, common.world_width);
    const y_offsets = common.wrapOffsets(rift.pos.y, radius + 24.0, common.world_height);

    for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
        const center = common.vec2(rift.pos.x + ox, rift.pos.y + oy);
        common.drawGlowDot(center, radius * 0.22, core_color, 0.9 * envelope);

        var prev = common.add(center, common.fromAngle(display_phase * 0.18, radius));
        for (1..19) |i| {
            const angle = display_phase * 0.18 + common.tau * (@as(f32, @floatFromInt(i)) / 18.0);
            const next = common.add(center, common.fromAngle(angle, radius * (0.92 + 0.08 * @sin(rift.pulse * 1.6 + angle * 2.0))));
            common.drawGlowLine(prev, next, 1.1, shell_color, 0.55 * envelope);
            prev = next;
        }

        for (0..4) |i| {
            const orbit = radius * (0.42 + @as(f32, @floatFromInt(i)) * 0.1);
            const angle = rift.pulse * (0.7 + @as(f32, @floatFromInt(i)) * 0.18) + @as(f32, @floatFromInt(i)) * (common.tau / 4.0);
            common.drawGlowDot(common.add(center, common.fromAngle(angle, orbit)), 3.2 + @as(f32, @floatFromInt(i)), shell_color, 0.55 * envelope);
        }
    };
}

fn drawBackground(game: *const Game) void {
    const horizon = @as(i32, @intFromFloat(90.0 + 25.0 * @sin(game.display_phase * 0.5)));
    const offsets = [_]f32{ -common.world_width, 0.0, common.world_width };
    for (offsets) |ox| {
        rl.drawRectangleGradientV(@as(i32, @intFromFloat(ox)), 0, common.world_width_i, common.world_height_i, common.rgba(3, 8, 14, 255), common.rgba(1, 2, 5, 255));
        rl.drawRectangleGradientV(@as(i32, @intFromFloat(ox)), common.world_height_i - horizon, common.world_width_i, horizon, common.rgba(4, 8, 15, 0), common.rgba(6, 14, 28, 120));
    }
}

fn drawStars(game: *const Game) void {
    for (game.stars) |star| {
        const pulse = 0.4 + 0.35 * (@sin(game.display_phase * 1.5 + star.phase) * 0.5 + 0.5);
        const color = common.rgba(120, 170, 255, @as(u8, @intFromFloat(100.0 * pulse)));
        const radius = star.size * 3.2;
        const x_offsets = common.wrapOffsets(star.pos.x, radius, common.world_width);
        const y_offsets = common.wrapOffsets(star.pos.y, radius, common.world_height);
        for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
            common.drawGlowDot(common.vec2(star.pos.x + ox, star.pos.y + oy), star.size, color, 0.18 + pulse * 0.1);
        };
    }
}

fn drawParticle(particle: Particle) void {
    const age = particle.life / particle.max_life;
    const color = common.withAlpha(particle.color, @as(u8, @intFromFloat(std.math.clamp(age * particle.intensity * 255.0, 0.0, 255.0))));
    const radius = switch (particle.kind) {
        .flash => particle.size * (0.6 + age) * 3.2,
        .ember => particle.size * 0.5 * 3.2,
        .shard => particle.size * (0.6 + age),
    };
    const x_offsets = common.wrapOffsets(particle.pos.x, radius, common.world_width);
    const y_offsets = common.wrapOffsets(particle.pos.y, radius, common.world_height);
    for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
        const pos = common.vec2(particle.pos.x + ox, particle.pos.y + oy);
        switch (particle.kind) {
            .flash => common.drawGlowDot(pos, particle.size * (0.6 + age), color, particle.intensity),
            .ember => common.drawGlowDot(pos, particle.size * 0.5, color, particle.intensity * 0.7),
            .shard => {
                const dir = common.fromAngle(particle.angle, particle.size * (0.6 + age));
                common.drawGlowLine(common.sub(pos, dir), common.add(pos, dir), 1.1 + age * 1.5, color, particle.intensity);
            },
        }
    };
}

fn drawBullet(bullet: Bullet) void {
    common.drawWrappedDot(bullet.pos, 3.4, if (bullet.owner == .player) common.rgba(210, 245, 255, 255) else common.rgba(255, 105, 180, 255), 0.75);
}

fn drawAsteroid(asteroid: Asteroid) void {
    const color = switch (asteroid.size) {
        .large => common.rgba(190, 220, 255, 255),
        .medium => common.rgba(230, 235, 255, 255),
        .small => common.rgba(255, 220, 190, 255),
    };
    const radius = asteroid.radius + 6.0;
    const x_offsets = common.wrapOffsets(asteroid.pos.x, radius, common.world_width);
    const y_offsets = common.wrapOffsets(asteroid.pos.y, radius, common.world_height);
    for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
        const center = common.vec2(asteroid.pos.x + ox, asteroid.pos.y + oy);
        for (0..asteroid.point_count) |i| {
            const current = common.rotate(asteroid.shape[i], asteroid.angle);
            const next = common.rotate(asteroid.shape[(i + 1) % asteroid.point_count], asteroid.angle);
            common.drawGlowLine(common.add(center, current), common.add(center, next), 1.4, color, 0.85);
        }
    };
}

fn drawShip(player: Player) void {
    const render_angle = player.angle + common.pi / 2.0;
    const nose = common.rotate(common.vec2(0.0, -18.0), render_angle);
    const right = common.rotate(common.vec2(12.0, 14.0), render_angle);
    const tail = common.rotate(common.vec2(0.0, 8.0), render_angle);
    const left = common.rotate(common.vec2(-12.0, 14.0), render_angle);
    const color = if (player.invuln_timer > 0.0) common.rgba(180, 220, 255, 255) else common.rgba(245, 250, 255, 255);

    const radius: f32 = if (player.thrusting) 30.0 else 22.0;
    const x_offsets = common.wrapOffsets(player.pos.x, radius, common.world_width);
    const y_offsets = common.wrapOffsets(player.pos.y, radius, common.world_height);
    for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
        const pos = common.vec2(player.pos.x + ox, player.pos.y + oy);
        common.drawGlowLine(common.add(pos, nose), common.add(pos, right), 1.4, color, 0.9);
        common.drawGlowLine(common.add(pos, right), common.add(pos, tail), 1.4, color, 0.9);
        common.drawGlowLine(common.add(pos, tail), common.add(pos, left), 1.4, color, 0.9);
        common.drawGlowLine(common.add(pos, left), common.add(pos, nose), 1.4, color, 0.9);
        if (player.thrusting) {
            const flame_a = common.rotate(common.vec2(-6.0, 13.0), render_angle);
            const flame_b = common.rotate(common.vec2(0.0, 28.0), render_angle);
            const flame_c = common.rotate(common.vec2(6.0, 13.0), render_angle);
            common.drawGlowLine(common.add(pos, flame_a), common.add(pos, flame_b), 1.0, common.rgba(255, 180, 100, 255), 0.85);
            common.drawGlowLine(common.add(pos, flame_b), common.add(pos, flame_c), 1.0, common.rgba(255, 210, 120, 255), 0.85);
        }
    };
}

fn drawSaucer(saucer: Saucer) void {
    const scale_factor: f32 = if (saucer.size == .large) 1.0 else 0.72;
    const w = 34.0 * scale_factor;
    const h = 16.0 * scale_factor;
    const color = if (saucer.size == .large) common.rgba(255, 160, 230, 255) else common.rgba(255, 110, 210, 255);
    const radius = w + 6.0;
    const x_offsets = common.wrapOffsets(saucer.pos.x, radius, common.world_width);
    const y_offsets = common.wrapOffsets(saucer.pos.y, h + 6.0, common.world_height);
    for (x_offsets.values[0..x_offsets.len]) |ox| for (y_offsets.values[0..y_offsets.len]) |oy| {
        const pos = common.vec2(saucer.pos.x + ox, saucer.pos.y + oy);
        common.drawGlowLine(common.vec2(pos.x - w, pos.y), common.vec2(pos.x - w * 0.55, pos.y - h), 1.4, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x - w * 0.55, pos.y - h), common.vec2(pos.x + w * 0.55, pos.y - h), 1.4, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x + w * 0.55, pos.y - h), common.vec2(pos.x + w, pos.y), 1.4, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x - w, pos.y), common.vec2(pos.x + w, pos.y), 1.4, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x - w * 0.7, pos.y), common.vec2(pos.x - w * 0.4, pos.y + h), 1.2, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x - w * 0.4, pos.y + h), common.vec2(pos.x + w * 0.4, pos.y + h), 1.2, color, 0.9);
        common.drawGlowLine(common.vec2(pos.x + w * 0.4, pos.y + h), common.vec2(pos.x + w * 0.7, pos.y), 1.2, color, 0.9);
    };
}

fn drawHud(game: *const Game, render_w: f32, render_h: f32) void {
    const zoom = uiZoom(render_w, render_h);
    var score_buf: [32]u8 = undefined;
    var high_buf: [32]u8 = undefined;
    const score_text = std.fmt.bufPrint(&score_buf, "{d:0>5}", .{game.score}) catch "00000";
    const high_text = std.fmt.bufPrint(&high_buf, "{d:0>5}", .{game.high_score}) catch "00000";
    font.drawText(score_text, uiPoint(42.0, 34.0, render_w, render_h), 24.0 * zoom, 6.0 * zoom, 1.5 * zoom, .left, common.rgba(210, 235, 255, 255));
    font.drawText(high_text, uiPoint(common.world_width - 42.0, 34.0, render_w, render_h), 24.0 * zoom, 6.0 * zoom, 1.5 * zoom, .right, common.rgba(145, 180, 230, 255));
    for (0..@as(usize, @intCast(@max(game.lives, 0)))) |i| {
        drawMiniShip(uiPoint(54.0 + @as(f32, @floatFromInt(i)) * 28.0, 88.0, render_w, render_h), common.rgba(200, 230, 255, 255), zoom);
    }
    if (game.rift.active and game.mode == .playing) {
        font.drawText("GRAVITY RIFT", uiPoint(common.world_width * 0.5, 34.0, render_w, render_h), 18.0 * zoom, 5.0 * zoom, 1.1 * zoom, .center, common.rgba(120, 190, 255, 255));
    }
}

fn drawTitle(game: *const Game, render_w: f32, render_h: f32) void {
    const zoom = uiZoom(render_w, render_h);
    font.drawText("ASTEROIDS", uiPoint(common.world_width * 0.5, 176.0, render_w, render_h), 62.0 * zoom, 16.0 * zoom, 1.8 * zoom, .center, common.rgba(214, 238, 255, 255));
    font.drawText("PRESS ENTER", uiPoint(common.world_width * 0.5, 294.0, render_w, render_h), 24.0 * zoom, 8.0 * zoom, 1.2 * zoom, .center, common.rgba(255, 170, 120, 255));
    font.drawText("VECTOR ARCADE", uiPoint(common.world_width * 0.5, 360.0 + @sin(game.title_spin * 3.0) * 7.0, render_w, render_h), 16.0 * zoom, 5.0 * zoom, 1.0 * zoom, .center, common.rgba(130, 170, 230, 255));
}

fn drawWaveMessage(game: *const Game, render_w: f32, render_h: f32) void {
    if (game.wave_message_timer <= 0.0) return;
    const zoom = uiZoom(render_w, render_h);
    var buf: [24]u8 = undefined;
    const text = std.fmt.bufPrint(&buf, "WAVE {d}", .{game.wave}) catch "WAVE";
    font.drawText(text, uiPoint(common.world_width * 0.5, 120.0, render_w, render_h), 28.0 * zoom, 8.0 * zoom, 1.5 * zoom, .center, common.rgba(255, 190, 120, 255));
}

fn drawGameOver(game: *const Game, render_w: f32, render_h: f32) void {
    const zoom = uiZoom(render_w, render_h);
    font.drawText("GAME OVER", uiPoint(common.world_width * 0.5, common.world_height * 0.5 - 32.0, render_w, render_h), 46.0 * zoom, 16.0 * zoom, 1.9 * zoom, .center, common.rgba(255, 150, 130, 255));
    font.drawText("PRESS ENTER", uiPoint(common.world_width * 0.5, common.world_height * 0.5 + 48.0, render_w, render_h), 24.0 * zoom, 9.0 * zoom, 1.3 * zoom, .center, common.rgba(220, 230, 255, 255));
    _ = game;
}

fn drawMiniShip(pos: common.Vec2, color: rl.Color, zoom: f32) void {
    common.drawGlowLine(common.vec2(pos.x, pos.y - 8.0 * zoom), common.vec2(pos.x + 6.0 * zoom, pos.y + 6.0 * zoom), 1.0 * zoom, color, 0.7);
    common.drawGlowLine(common.vec2(pos.x + 6.0 * zoom, pos.y + 6.0 * zoom), common.vec2(pos.x - 6.0 * zoom, pos.y + 6.0 * zoom), 1.0 * zoom, color, 0.7);
    common.drawGlowLine(common.vec2(pos.x - 6.0 * zoom, pos.y + 6.0 * zoom), common.vec2(pos.x, pos.y - 8.0 * zoom), 1.0 * zoom, color, 0.7);
}

fn uiZoom(render_w: f32, render_h: f32) f32 {
    _ = render_w;
    return @min(render_h / common.world_height, 1.0);
}

fn uiPoint(world_x: f32, world_y: f32, render_w: f32, render_h: f32) common.Vec2 {
    return common.vec2(
        (world_x / common.world_width) * render_w,
        (world_y / common.world_height) * render_h,
    );
}

test "torus delta prefers wrapped path" {
    const delta = common.torusDelta(common.vec2(10.0, 10.0), common.vec2(common.world_width - 5.0, 20.0));
    try std.testing.expectApproxEqAbs(-15.0, delta.x, 0.001);
}
