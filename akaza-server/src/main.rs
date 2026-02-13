mod handler;
mod jsonrpc;

use std::io::{self, BufRead, Write};
use std::sync::{Arc, Mutex};

use anyhow::Result;
use libakaza::config::EngineConfig;
use libakaza::engine::bigram_word_viterbi_engine::BigramWordViterbiEngineBuilder;
use libakaza::graph::reranking::ReRankingWeights;
use libakaza::user_side_data::user_data::UserData;
use log::info;

fn main() -> Result<()> {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .target(env_logger::Target::Stderr)
        .init();

    let model_dir = match std::env::args().nth(1) {
        Some(path) => path,
        None => {
            eprintln!("Usage: akaza-server <model-directory>");
            std::process::exit(1);
        }
    };

    info!("Starting akaza-server with model: {}", model_dir);

    let user_data = Arc::new(Mutex::new(
        UserData::load_from_default_path().unwrap_or_default(),
    ));

    let config = EngineConfig {
        model: model_dir,
        dicts: vec![],
        dict_cache: true,
        reranking_weights: ReRankingWeights::default(),
    };

    let engine = BigramWordViterbiEngineBuilder::new(config)
        .user_data(user_data)
        .build()?;

    info!("Engine initialized successfully");

    let mut handler = handler::Handler::new(engine);

    let stdin = io::stdin();
    let mut stdout = io::stdout();

    for line in stdin.lock().lines() {
        let line = match line {
            Ok(l) => l,
            Err(e) => {
                log::error!("Failed to read stdin: {}", e);
                break;
            }
        };

        if line.is_empty() {
            continue;
        }

        let response = handler.handle_request(&line);
        writeln!(stdout, "{}", response)?;
        stdout.flush()?;
    }

    info!("akaza-server shutting down");
    Ok(())
}
