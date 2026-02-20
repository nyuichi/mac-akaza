use std::collections::HashMap;
use std::ops::Range;

use libakaza::dict::skk::write::write_skk_dict;
use libakaza::engine::base::HenkanEngine;
use libakaza::engine::bigram_word_viterbi_engine::BigramWordViterbiEngine;
use libakaza::graph::candidate::Candidate;
use libakaza::kana_kanji::base::KanaKanjiDict;
use libakaza::lm::base::{SystemBigramLM, SystemUnigramLM};
use libakaza::lm::system_unigram_lm::MarisaSystemUnigramLM;
use log::{error, info};
use serde_json::Value;

use crate::jsonrpc::*;

pub struct Handler<U: SystemUnigramLM, B: SystemBigramLM, KD: KanaKanjiDict> {
    engine: BigramWordViterbiEngine<U, B, KD>,
    dict_path: String,
    model_dir: String,
}

impl<U: SystemUnigramLM, B: SystemBigramLM, KD: KanaKanjiDict> Handler<U, B, KD> {
    pub fn new(
        engine: BigramWordViterbiEngine<U, B, KD>,
        dict_path: String,
        model_dir: String,
    ) -> Self {
        Self {
            engine,
            dict_path,
            model_dir,
        }
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
            "user_dict_list" => self.handle_user_dict_list(&request),
            "user_dict_add" => self.handle_user_dict_add(&request),
            "user_dict_delete" => self.handle_user_dict_delete(&request),
            "model_info" => self.handle_model_info(&request),
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

        // Persist learned data to disk
        match self.engine.user_data.lock() {
            Ok(mut user_data) => {
                if let Err(e) = user_data.write_user_files() {
                    error!("learn: failed to save user data: {}", e);
                    return Response::error(
                        request.id.clone(),
                        INTERNAL_ERROR,
                        format!("Failed to save learned data: {}", e),
                    );
                }
            }
            Err(e) => {
                error!("learn: failed to lock user_data: {}", e);
                return Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    "Failed to access user data".to_string(),
                );
            }
        }

        Response::success(request.id.clone(), Value::Bool(true))
    }

    fn handle_user_dict_list(&self, request: &Request) -> Response {
        match self.engine.user_data.lock() {
            Ok(user_data) => {
                let mut entries: Vec<UserDictEntry> = user_data
                    .dict
                    .iter()
                    .map(|(yomi, surfaces)| UserDictEntry {
                        yomi: yomi.clone(),
                        surfaces: surfaces.clone(),
                    })
                    .collect();
                entries.sort_by(|a, b| a.yomi.cmp(&b.yomi));
                Response::success(request.id.clone(), serde_json::to_value(entries).unwrap())
            }
            Err(e) => {
                error!("user_dict_list: failed to lock user_data: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    "Failed to access user data".to_string(),
                )
            }
        }
    }

    fn handle_user_dict_add(&self, request: &Request) -> Response {
        let params: UserDictAddParams = match serde_json::from_value(request.params.clone()) {
            Ok(p) => p,
            Err(e) => {
                return Response::error(
                    request.id.clone(),
                    INVALID_PARAMS,
                    format!("Invalid params: {}", e),
                );
            }
        };

        match self.engine.user_data.lock() {
            Ok(mut user_data) => {
                {
                    let surfaces = user_data.dict.entry(params.yomi.clone()).or_default();
                    if !surfaces.contains(&params.surface) {
                        surfaces.push(params.surface.clone());
                    }
                }

                // Persist to disk
                let dict: HashMap<String, Vec<String>> =
                    user_data.dict.clone().into_iter().collect();
                if let Err(e) = write_skk_dict(&self.dict_path, vec![dict]) {
                    error!("user_dict_add: failed to write dict: {}", e);
                    return Response::error(
                        request.id.clone(),
                        INTERNAL_ERROR,
                        format!("Failed to save dictionary: {}", e),
                    );
                }

                info!(
                    "Added user dict entry: {} -> {}",
                    params.yomi, params.surface
                );
                Response::success(request.id.clone(), Value::Bool(true))
            }
            Err(e) => {
                error!("user_dict_add: failed to lock user_data: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    "Failed to access user data".to_string(),
                )
            }
        }
    }

    fn handle_user_dict_delete(&self, request: &Request) -> Response {
        let params: UserDictDeleteParams = match serde_json::from_value(request.params.clone()) {
            Ok(p) => p,
            Err(e) => {
                return Response::error(
                    request.id.clone(),
                    INVALID_PARAMS,
                    format!("Invalid params: {}", e),
                );
            }
        };

        match self.engine.user_data.lock() {
            Ok(mut user_data) => {
                if let Some(surfaces) = user_data.dict.get_mut(&params.yomi) {
                    surfaces.retain(|s| s != &params.surface);
                    if surfaces.is_empty() {
                        user_data.dict.remove(&params.yomi);
                    }
                }

                // Persist to disk
                let dict: HashMap<String, Vec<String>> =
                    user_data.dict.clone().into_iter().collect();
                if let Err(e) = write_skk_dict(&self.dict_path, vec![dict]) {
                    error!("user_dict_delete: failed to write dict: {}", e);
                    return Response::error(
                        request.id.clone(),
                        INTERNAL_ERROR,
                        format!("Failed to save dictionary: {}", e),
                    );
                }

                info!(
                    "Deleted user dict entry: {} / {}",
                    params.yomi, params.surface
                );
                Response::success(request.id.clone(), Value::Bool(true))
            }
            Err(e) => {
                error!("user_dict_delete: failed to lock user_data: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    "Failed to access user data".to_string(),
                )
            }
        }
    }

    fn handle_model_info(&self, request: &Request) -> Response {
        let unigram_path = format!("{}/unigram.model", self.model_dir);
        match MarisaSystemUnigramLM::load(&unigram_path) {
            Ok(lm) => {
                let metadata = lm.metadata();
                let result = ModelInfoResult {
                    akaza_data_version: metadata.akaza_data_version,
                    build_timestamp: metadata.build_timestamp,
                };
                Response::success(request.id.clone(), serde_json::to_value(result).unwrap())
            }
            Err(e) => {
                error!("model_info: failed to load unigram model: {}", e);
                Response::error(
                    request.id.clone(),
                    INTERNAL_ERROR,
                    format!("Failed to load model: {}", e),
                )
            }
        }
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
