use serde::{Deserialize, Serialize};
use serde_json::Value;

// JSON-RPC 2.0 error codes
pub const PARSE_ERROR: i64 = -32700;
pub const METHOD_NOT_FOUND: i64 = -32601;
pub const INVALID_PARAMS: i64 = -32602;
pub const INTERNAL_ERROR: i64 = -32603;

#[derive(Debug, Deserialize)]
pub struct Request {
    #[allow(dead_code)]
    pub jsonrpc: String,
    pub id: Value,
    pub method: String,
    #[serde(default)]
    pub params: Value,
}

#[derive(Debug, Deserialize)]
pub struct ConvertParams {
    pub yomi: String,
}

#[derive(Debug, Deserialize)]
pub struct ConvertKBestParams {
    pub yomi: String,
    pub k: usize,
}

#[derive(Debug, Deserialize)]
pub struct LearnParams {
    pub candidates: Vec<LearnCandidate>,
}

#[derive(Debug, Deserialize)]
pub struct LearnCandidate {
    pub surface: String,
    pub yomi: String,
}

#[derive(Debug, Serialize)]
pub struct CandidateResult {
    pub surface: String,
    pub yomi: String,
    pub cost: f32,
}

#[derive(Debug, Serialize)]
pub struct Response {
    pub jsonrpc: String,
    pub id: Value,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub result: Option<Value>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub error: Option<RpcError>,
}

#[derive(Debug, Serialize)]
pub struct RpcError {
    pub code: i64,
    pub message: String,
}

impl Response {
    pub fn success(id: Value, result: Value) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            id,
            result: Some(result),
            error: None,
        }
    }

    pub fn error(id: Value, code: i64, message: String) -> Self {
        Self {
            jsonrpc: "2.0".to_string(),
            id,
            result: None,
            error: Some(RpcError { code, message }),
        }
    }
}
