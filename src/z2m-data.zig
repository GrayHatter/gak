pub const Z2m = struct {
    pub const bridge = struct {
        pub const state = struct {};
        pub const info = struct {
            commit: ?[]const u8 = null,
            config: ?struct {} = null,
            config_schema: ?struct {} = null,
            coordinator: ?struct {
                ieee_address: []const u8,
                meta: struct {},
                type: []const u8,
            } = null,
            log_level: ?[]const u8 = null,
            network: ?struct {
                channel: usize,
                extended_pan_id: usize,
                pan_id: usize,
            } = null,
            permit_join: bool,
            restart_required: bool,
            version: []const u8,
            zigbee_herdsman: struct {
                version: []const u8,
            },
            zigbee_herdsman_converters: struct {
                version: []const u8,
            },
        };
        pub const logging = struct {
            level: []const u8,
            message: []const u8,
        };
        pub const groups = struct {
            friendly_name: []const u8,
            id: usize,
            members: []struct {
                endpoint: usize,
                ieee_address: []const u8,
            },
            scenes: []struct {
                id: usize,
                name: []const u8,
            },
        };
        pub const definitions = struct {};
        pub const extensions = struct {};

        pub const devices = struct {
            definition: ?Definition = null,
            date_code: ?[]const u8 = null,
            disabled: ?bool = null,
            endpoints: ?Endpoints = null,
            friendly_name: ?[]const u8 = null,
            ieee_address: ?[]const u8 = null,
            interview_completed: ?bool = null,
            interviewing: ?bool = null,
            network_address: ?usize = null,
            supported: ?bool = null,
            type: ?[]const u8 = null,
            manufacturer: ?[]const u8 = null,
            model_id: ?[]const u8 = null,
            power_source: ?[]const u8 = null,
            software_build_id: ?[]const u8 = null,

            pub const Definition = struct {
                description: ?[]const u8,
                exposes: ?[]Exposed = null,
                model: ?[]const u8 = null,
                options: ?[]struct {} = null,
                supports_ota: ?bool = null,
                vendor: ?[]const u8 = null,
            };

            pub const Exposed = struct {
                features: ?[]struct {
                    access: ?usize = null,
                    description: ?[]const u8 = null,
                    label: ?[]const u8 = null,
                    name: ?[]const u8 = null,
                    property: ?[]const u8 = null,
                    type: ?[]const u8 = null,
                    value_off: ?[]const u8 = null,
                    value_on: ?[]const u8 = null,
                    value_toggle: ?[]const u8 = null,
                } = null,
                description: ?[]const u8 = null,
                name: ?[]const u8 = null,
            };

            pub const Endpoints = struct {
                @"1": ?EndpointObject = null,
                @"2": ?EndpointObject = null,
                @"3": ?EndpointObject = null,
                @"4": ?EndpointObject = null,
                @"242": ?EndpointObject = null,
            };

            pub const EndpointObject = struct {
                bindings: ?[]struct {
                    cluster: ?[]const u8,
                    target: ?struct {
                        endpoint: ?usize = null,
                        ieee_address: ?[]const u8,
                        type: ?[]const u8 = null,
                    },
                    configured_reportings: ?[]struct {
                        attribute: ?[]const u8 = null,
                        cluster: ?[]const u8 = null,
                        maximum_report_interval: usize,
                        minimum_report_interval: usize,
                        reportable_change: ?usize = null,
                    } = null,
                    scenes: ?[]struct {} = null,
                } = null,
                clusters: ?struct {
                    input: ?[][]const u8 = null,
                    output: ?[][]const u8 = null,
                } = null,
            };
        };
    };
};
