const sun = @This();

pub const AzEl = struct {
    azimuth: f64,
    elevation: f64,
};

const ExactPos = struct {
    year: usize,
    month: usize,
    day: usize,
    time_local: f64,
    lat: f64,
    lon: f64,
    tz: f16,

    fn leapYear(year: usize) bool {
        return year % 4 == 0 and (year % 100 != 0 or year % 400 == 0);
    }

    const DAYS_IN_MONTH = [_]u8{ 0, 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    fn monthsFrom(year: usize, days: usize) struct { u8, usize } {
        std.debug.assert(days <= 366);
        var m: u8 = 1;
        var d: usize = days;
        if (d >= 60 and leapYear(year)) {
            d -= 1; // LOL
        }
        while (d > DAYS_IN_MONTH[m]) {
            d -= DAYS_IN_MONTH[m];
            m += 1;
        }
        return .{ m, d };
    }

    pub fn fromTimestamp(timestamp: i64, tz: f16, lat: f64, lon: f64) ExactPos {
        if (timestamp < 0) unreachable;
        const ts: usize = @intCast(timestamp);
        const year = yearsFrom(ts);

        const days = 719162 + ts / 60 / 60 / 24 - daysAtYear(year);
        const both = monthsFrom(year, days);
        const month = both[0];
        const day: usize = @truncate(both[1] + 1);

        const secs: f64 = @floatFromInt(ts % 60);
        const mins: f64 = @floatFromInt(ts / 60 % 60);
        const hour: f64 = @floatFromInt(ts / 60 / 60 % 24);
        const time: f64 = hour * 60.0 + mins + secs / 60.0;
        return .{
            .year = year,
            .month = month,
            .day = day,
            .time_local = time,
            .lat = lat,
            .lon = lon,
            .tz = tz,
        };
    }

    fn daysAtYear(year: usize) usize {
        const y = year - 1;
        return y * 365 + @divFloor(y, 4) - @divFloor(y, 100) + @divFloor(y, 400);
    }

    fn yearsFrom(epoch: usize) usize {
        const days = epoch / 60 / 60 / 24 + 719162;
        var year = days / 365;
        while (days < daysAtYear(year)) year -= 1;
        std.debug.assert(days >= daysAtYear(year));
        return year;
    }

    pub fn toJulien(exact: ExactPos) f64 {
        var year: f64 = @floatFromInt(exact.year);
        var month: f64 = @floatFromInt(exact.month);
        if (month <= 2) {
            year -= 1;
            month += 12;
        }
        const day: f64 = @floatFromInt(exact.day);

        const a: f64 = @divFloor(year, 100.0);
        const b: f64 = 2.0 - a + @divFloor(a, 4.0);
        return @floor(365.25 * (year + 4716.0)) + @floor(30.6001 * (month + 1.0)) + day + b - 1524.5;
    }
};

fn julianCentury(jd: f64) f64 {
    return (jd - 2451545.0) / 36525.0;
}

fn meanObliquityOfEcliptic(t: f64) f64 {
    const seconds = 21.448 - t * (46.8150 + t * (0.00059 - t * (0.001813)));
    return 23.0 + (26.0 + (seconds / 60.0)) / 60.0;
}

fn obliquityCorrection(t: f64) f64 {
    return meanObliquityOfEcliptic(t) + 0.00256 * cos(dtr(125.04 - 1934.136 * t));
}

fn equationOfTime(t: f64) f64 {
    const l0 = @mod(280.46646 + t * (36000.76983 + t * (0.0003032)), 360);
    const e = 0.016708634 - t * (0.000042037 + 0.0000001267 * t);
    const m = 357.52911 + t * (35999.05029 - 0.0001537 * t);

    var y = tan(dtr(obliquityCorrection(t)) / 2.0);
    y *= y;

    const dl0 = dtr(l0);
    const sinm = sin(dtr(m));

    const etime = y * sin(2.0 * dl0) -
        2.0 * e * sinm +
        4.0 * e * y * sinm * cos(2.0 * dl0) -
        0.5 * y * y * sin(4.0 * dl0) -
        1.25 * e * e * sin(2.0 * dtr(m));
    return rtd(etime) * 4.0;
}

fn geomMeanLong(t: f64) f64 {
    return @mod(280.46646 + t * (36000.76983 + t * (0.0003032)), 360.0);
}

fn geomMeanAnomaly(t: f64) f64 {
    return 357.52911 + t * (35999.05029 - 0.0001537 * t);
}

fn eqOfCenter(t: f64) f64 {
    const mrad = dtr(geomMeanAnomaly(t));
    return sin(mrad) * (1.914602 - t * (0.004817 + 0.000014 * t)) +
        sin(mrad + mrad) * (0.019993 - 0.000101 * t) +
        sin(mrad + mrad + mrad) * 0.000289;
}

fn apparentLong(t: f64) f64 {
    const omega = 125.04 - 1934.136 * t;
    return geomMeanLong(t) + eqOfCenter(t) - 0.00569 - 0.00478 * sin(dtr(omega));
}

fn trueAnomaly(t: f64) f64 {
    return geomMeanAnomaly(t) + eqOfCenter(t);
}

fn declination(t: f64) f64 {
    return rtd(arcsin(sin(dtr(obliquityCorrection(t))) * sin(dtr(apparentLong(t)))));
}

fn refraction(el: f64) f64 {
    if (el > 85.0) return 0.0;

    var correction: f64 = 0.0;
    const te = tan(dtr(el));
    if (el > 5.0) {
        correction = 58.1 / te - 0.07 / (te * te * te) + 0.000086 / (te * te * te * te * te);
    } else if (el > -0.575) {
        correction = 1735.0 + el * (-518.2 + el * (103.4 + el * (-12.79 + el * 0.711)));
    } else {
        correction = -20.774 / te;
    }
    correction = correction / 3600.0;

    return correction;
}

fn noon(jd: f64, lon: f64, timezone: f64) f64 {
    const tnoon = julianCentury(jd - lon / 360.0);
    var eqt = equationOfTime(tnoon);
    const solNoonOffset = 720.0 - (lon * 4) - eqt;

    const newt = julianCentury(jd - 0.5 + solNoonOffset / 1440.0);
    eqt = equationOfTime(newt);
    var noon_local = 720 - (lon * 4) - eqt + (timezone * 60.0);
    while (noon_local < 0.0) {
        noon_local += 1440.0;
    }
    while (noon_local >= 1440.0) {
        noon_local -= 1440.0;
    }

    return noon_local;
}

pub fn azel(time: f64, local: f64, lat: f64, lon: f64, tz: f64) AzEl {
    const theta = declination(time);

    var true_time = local + equationOfTime(time) + 4.0 * lon - 60.0 * tz;
    while (true_time > 1440) true_time -= 1440;
    var ha = true_time / 4.0 - 180.0;
    if (ha < -180) ha += 360.0;

    var csz = sin(dtr(lat)) * sin(dtr(theta)) + cos(dtr(lat)) * cos(dtr(theta)) * cos(dtr(ha));
    csz = @max(-1.0, @min(csz, 1.0));

    const zenith = rtd(arccos(csz));
    const az_denom = (cos(dtr(lat)) * sin(dtr(zenith)));
    var azimuth: f64 = 0.0;
    if (@abs(az_denom) > 0.001) {
        const azr = ((sin(dtr(lat)) * cos(dtr(zenith))) - sin(dtr(theta))) / az_denom;
        azimuth = 180.0 - rtd(arccos(@max(-1.0, @min(azr, 1.0))));
        if (ha > 0.0) azimuth = -azimuth;
    } else {
        if (lat > 0.0) azimuth = 180.0;
    }

    if (azimuth < 0.0) azimuth += 360.0;

    const elevation = 90.0 - (zenith - refraction(90.0 - zenith));

    return .{
        .azimuth = azimuth,
        .elevation = elevation,
    };
}

pub fn build(exact: ExactPos) f64 {
    const jday = exact.toJulien();
    const T = julianCentury(jday + exact.time_local / 1440.0 - exact.tz / 24.0);
    const az_el = azel(T, exact.time_local, exact.lat, exact.lon, exact.tz);
    return az_el.elevation;
}

test build {
    const lat = 35.0;
    const lon = -120.0;
    const exact: ExactPos = .{
        .year = 2025,
        .month = 1,
        .day = 24,
        .time_local = 16 * 60 + 24 + 20.0 / 60.0,
        .lat = lat,
        .lon = lon,
        .tz = -8.0,
    };
    // Technically, I didn't actually verify this value is correct, but I'm
    // unwilling to commit my exact lat/lon to a public git repo, just yet!
    try std.testing.expectEqual(build(exact), 9.605713096813815);
    const time = std.time.timestamp() - 8 * 60 * 60;
    const ets = ExactPos.fromTimestamp(time, -8.0, lat, lon);
    _ = build(ets);
}

const std = @import("std");
const sin = std.math.sin;
const cos = std.math.cos;
const tan = std.math.tan;
const dtr = std.math.degreesToRadians;
const rtd = std.math.radiansToDegrees;
const arcsin = std.math.asin;
const arccos = std.math.acos;
