use std::ops::Range;

use libakaza::engine::base::HenkanEngine;
use libakaza::engine::bigram_word_viterbi_engine::BigramWordViterbiEngine;
use libakaza::graph::candidate::Candidate;
use libakaza::kana_kanji::base::KanaKanjiDict;
use libakaza::lm::base::{SystemBigramLM, SystemUnigramLM};
use log::{error, info};
use serde_json::Value;

use crate::jsonrpc::*;

pub struct Handler<U: SystemUnigramLM, B: SystemBigramLM, KD: KanaKanjiDict> {
    engine: BigramWordViterbiEngine<U, B, KD>,
}

impl<U: SystemUnigramLM, B: SystemBigramLM, KD: KanaKanjiDict> Handler<U, B, KD> {
    pub fn new(engine: BigramWordViterbiEngine<U, B, KD>) -> Self {
        Self { engine }
    }

    pub fn handle_request(&mut self, line: &str) -> String {
        let request: Request = match serde_json::from_str(line) {
            Ok(req) => req,
            Err(e) => {
                error!("Failed to parse request: {}", e);
                let resp = Response::error(Value::Null, PARSE_ERROR, format!("Parse error: {}", e));
                return serde_json::to_string(&resp).unwrap();
            }
        };

        info!("Received request: method={}", request.method);

        let response = match request.method.as_str() {
            "convert" => self.handle_convert(&request),
            "convert_k_best" => self.handle_convert_k_best(&request),
            "learn" => self.handle_learn(&request),
            _ => Response::error(
                request.id,
                METHOD_NOT_FOUND,
                format!("Method not found: {}", request.method),
            ),
        };

        serde_json::to_string(&response).unwrap()
    }

    fn handle_convert(&self, request: &Request) -> Response {
        let params: ConvertParams = match serde_json::from_value(request.params.clone()) {
            Ok(p) => p,
            Err(e) => {
                return Response::error(
                    request.id.clone(),
                    INVALID_PARAMS,
                    format!("Invalid params: {}", e),
                );
            }
        };

        let force_ranges: Option<Vec<Range<usize>>> = params
            .force_ranges
            .map(|ranges| ranges.into_iter().map(|r| r[0]..r[1]).collect());

        match self.engine.convert(&params.yomi, force_ranges.as_deref()) {
            Ok(clauses) => {
                let result = Self::clauses_to_json(&clauses);
                Response::success(request.id.clone(), result)
            }
            Err(e) => {
                error!("convert failed: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    format!("Conversion failed: {}", e),
                )
            }
        }
    }

    fn handle_convert_k_best(&self, request: &Request) -> Response {
        let params: ConvertKBestParams = match serde_json::from_value(request.params.clone()) {
            Ok(p) => p,
            Err(e) => {
                return Response::error(
                    request.id.clone(),
                    INVALID_PARAMS,
                    format!("Invalid params: {}", e),
                );
            }
        };

        match self.engine.convert_k_best(&params.yomi, None, params.k) {
            Ok(paths) => {
                let result: Vec<Value> = paths
                    .iter()
                    .map(|path| {
                        serde_json::json!({
                            "segments": Self::clauses_to_json(&path.segments),
                            "cost": path.cost,
                        })
                    })
                    .collect();
                Response::success(request.id.clone(), Value::Array(result))
            }
            Err(e) => {
                error!("convert_k_best failed: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    format!("Conversion failed: {}", e),
                )
            }
        }
    }

    fn handle_learn(&mut self, request: &Request) -> Response {
        let params: LearnParams = match serde_json::from_value(request.params.clone()) {
            Ok(p) => p,
            Err(e) => {
                return Response::error(
                    request.id.clone(),
                    INVALID_PARAMS,
                    format!("Invalid params: {}", e),
                );
            }
        };

        let candidates: Vec<Candidate> = params
            .candidates
            .iter()
            .map(|c| Candidate::new(&c.yomi, &c.surface, 0.0))
            .collect();

        self.engine.learn(&candidates);
        info!("Learned {} candidates", candidates.len());

        Response::success(request.id.clone(), Value::Bool(true))
    }

    fn clauses_to_json(clauses: &[Vec<Candidate>]) -> Value {
        let result: Vec<Vec<CandidateResult>> = clauses
            .iter()
            .map(|clause| {
                clause
                    .iter()
                    .map(|c| CandidateResult {
                        surface: c.surface.clone(),
                        yomi: c.yomi.clone(),
                        cost: c.cost,
                    })
                    .collect()
            })
            .collect();
        serde_json::to_value(result).unwrap()
    }
}
