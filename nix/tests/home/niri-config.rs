// Probe the pinned compositor's actual parser, not a second KDL implementation.
use niri_config::{Action, Config, OutputName};
use std::path::Path;

fn main() {
    let path = std::env::args().nth(1).expect("configuration path");
    let cfg = Config::load(Path::new(&path)).config.expect("valid config");
    println!("gaps={}", cfg.layout.gaps);
    println!("mouse-left-handed={}", cfg.input.mouse.left_handed);
    println!("mouse-speed={}", cfg.input.mouse.accel_speed.0);
    println!("touchpad-tap={}", cfg.input.touchpad.tap);
    println!("touchpad-speed={}", cfg.input.touchpad.accel_speed.0);
    println!(
        "touchpad-natural-scroll={}",
        cfg.input.touchpad.natural_scroll
    );
    println!("keyboard-layout={}", cfg.input.keyboard.xkb.layout);
    for name in ["DP-5", "DP-6"] {
        let output = OutputName {
            connector: name.into(),
            make: None,
            model: None,
            serial: None,
        };
        if let Some(scale) = cfg.outputs.find(&output).and_then(|o| o.scale) {
            println!("{name}-scale={}", scale.0);
        }
    }
    for key in ["Mod+M", "Mod+B", "Mod+T"] {
        let key_value = key.parse().unwrap();
        if let Some(bind) = cfg.binds.0.iter().find(|b| b.key == key_value) {
            if let Action::Spawn(command) = &bind.action {
                println!("{key}={}", command.join(" "));
            }
        }
    }
    println!("startup-count={}", cfg.spawn_at_startup.len());
    // These fixtures only use app-id matches. Report parsed rule order so the
    // test can check the last applicable open-floating assignment.
    let floating: Vec<_> = cfg
        .window_rules
        .iter()
        .filter(|r| {
            r.matches.is_empty()
                || r.matches
                    .iter()
                    .any(|m| m.app_id.as_ref().is_some_and(|re| re.0.is_match("mpv")))
        })
        .filter_map(|r| r.open_floating)
        .map(|v| v.to_string())
        .collect();
    println!("mpv-floating-rules={}", floating.join(","));
}
