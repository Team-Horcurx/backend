import json
import os

import boto3

_bedrock = None


def _client():
    global _bedrock
    if _bedrock is None:
        _bedrock = boto3.client(
            "bedrock-runtime",
            region_name=os.environ.get("BEDROCK_REGION", "us-east-1"),
        )
    return _bedrock


def _invoke_llama(model_id: str, prompt: str, max_tokens: int = 512) -> str:
    """Meta Llama models on Bedrock use a `prompt` field wrapped in the
    Llama instruction template; response body has `generation`."""
    body = {
        "prompt": f"<|begin_of_text|><|start_header_id|>user<|end_header_id|>\n\n{prompt}<|eot_id|><|start_header_id|>assistant<|end_header_id|>\n\n",
        "max_gen_len": max_tokens,
        "temperature": 0.4,
    }
    resp = _client().invoke_model(
        modelId=model_id,
        body=json.dumps(body),
        contentType="application/json",
        accept="application/json",
    )
    payload = json.loads(resp["body"].read())
    return payload.get("generation", "").strip()


def explain_property(prop: dict) -> str:
    model_id = os.environ.get("BEDROCK_EXPLAIN_MODEL_ID", "us.meta.llama4-scout-17b-instruct-v1:0")
    conf_pct = round(prop["confidence"] * 100)
    type_label = "new construction" if prop["detection_type"] == "new_build" else "change of use"
    cb = prop.get("confidence_breakdown") or {}
    prompt = (
        "You are a GVMC (Greater Visakhapatnam Municipal Corporation) property-tax assessment assistant. "
        "Write a concise markdown explanation (3 short paragraphs max) for a field officer reviewing a satellite-detected "
        f"property anomaly. Property id: {prop['id']}. Detection type: {type_label}. Confidence: {conf_pct}%. "
        f"Area: {prop['area_sqm']} sqm. Confidence breakdown signals: {json.dumps(cb)}. "
        "Explain what the signals suggest and give one clear recommendation (schedule field verification if confidence "
        "is high, otherwise include in next inspection cycle). Use **bold** for key terms."
    )
    try:
        return _invoke_llama(model_id, prompt)
    except Exception as e:
        print(f"[BEDROCK ERROR] explain_property: {e}")
        priority = "High priority — schedule field verification within 7 days." if prop["confidence"] >= 0.8 else "Moderate priority — include in next inspection cycle."
        return (
            f"**Analysis for {prop['id']}**: Confidence {conf_pct}% for {type_label}.\n\n"
            "NDBI delta indicates built-up area increase since last satellite pass. No matching structure found in GVMC property records.\n\n"
            f"**Recommendation**: {priority}"
        )


def commissioner_brief(totals: dict, ward_rows: list[dict]) -> str:
    model_id = os.environ.get("BEDROCK_EXPLAIN_MODEL_ID", "us.meta.llama4-scout-17b-instruct-v1:0")
    prompt = (
        "You are a GVMC commissioner's briefing assistant. Write a concise markdown daily detection brief "
        "(executive summary, 2-3 high-priority wards, a metrics table, and one recommendation) from this data. "
        f"Totals: {json.dumps(totals)}. Per-ward breakdown: {json.dumps(ward_rows)}. "
        "Keep it under 250 words, use markdown headers and a table."
    )
    try:
        return _invoke_llama(model_id, prompt, max_tokens=768)
    except Exception as e:
        print(f"[BEDROCK ERROR] commissioner_brief: {e}")
        return (
            f"## GVMC Daily Detection Brief\n\n**Executive Summary**: {totals.get('total_detections', 0)} properties "
            f"flagged across {len(ward_rows)} wards. Revenue at risk: ₹{totals.get('revenue_estimate', 0):,}/year.\n\n"
            "AI brief generation is temporarily unavailable — showing raw totals only."
        )


def chat_reply(message: str, context_stats: dict, top_wards: list[dict]) -> str:
    model_id = os.environ.get("BEDROCK_CHAT_MODEL_ID", "us.meta.llama3-3-70b-instruct-v1:0")
    prompt = (
        "You are the GVMC field-officer assistant chatbot for a property-tax change-detection dashboard. "
        f"Current citywide stats: {json.dumps(context_stats)}. Top wards by pending detections: {json.dumps(top_wards)}. "
        f"Answer the officer's question using this data where relevant, in markdown, concisely. Question: {message}"
    )
    try:
        return _invoke_llama(model_id, prompt)
    except Exception as e:
        print(f"[BEDROCK ERROR] chat_reply: {e}")
        return (
            "I'm having trouble reaching the AI service right now. Based on the latest snapshot: "
            f"**{context_stats.get('total_detections', 0)} total detections**, "
            f"**{context_stats.get('pending_verification', 0)} pending verification**, "
            f"estimated revenue at risk **₹{context_stats.get('revenue_estimate', 0):,}/year**."
        )
