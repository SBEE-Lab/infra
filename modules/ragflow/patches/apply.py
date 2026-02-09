#!/usr/bin/env python3
"""
RAGFlow runtime patches for OpenSearch deployment.
Applied at container startup via entrypoint-wrapper.sh.

Each patch targets a specific upstream bug with a tracking issue/PR reference.
"""

import logging
import os

logging.basicConfig(level=logging.INFO, format="%(levelname)s: %(message)s")
log = logging.getLogger("ragflow-patches")


def patch_oidc_login():
    """Fix OIDC login (upstream PR #12784, issues #9601 #9747 #12568 #12892).

    Two problems:
    1. Frontend getAuthorization() adds "Bearer " prefix to URL auth token,
       but backend _load_user() doesn't strip it → signature mismatch.
    2. React wrapper doesn't execute after Vite migration, so useOAuthCallback
       hook's setAuthorization() never runs → token not persisted to localStorage.

    Fix: Inject inline script before React loads to persist ?auth= token,
         and remove "Bearer " prefix from auth header in API requests.
    """
    # 1. Inject inline script to persist ?auth= token before React loads
    index_html = "/ragflow/web/dist/index.html"
    if os.path.exists(index_html):
        with open(index_html) as f:
            html = f.read()
        snippet = (
            '<script>!function(){var a=new URLSearchParams(location.search).get("auth");'
            'if(a){localStorage.setItem("Authorization",a);'
            'var u=new URL(location);u.searchParams.delete("auth");'
            'history.replaceState({},"",u)}}()</script>'
        )
        marker = '<script type="module"'
        if snippet not in html and marker in html:
            html = html.replace(marker, snippet + marker, 1)
            with open(index_html, "w") as f:
                f.write(html)
            log.info("Patched index.html: injected ?auth= persistence script")

    # 2. Remove "Bearer " prefix from auth token in API requests
    js_dir = "/ragflow/web/dist/entry/js"
    if os.path.isdir(js_dir):
        for name in os.listdir(js_dir):
            if name.startswith("index-") and name.endswith(".js"):
                js_path = os.path.join(js_dir, name)
                with open(js_path) as f:
                    js = f.read()
                if '"Bearer "+e' in js:
                    js = js.replace('"Bearer "+e', "e", 1)
                    with open(js_path, "w") as f:
                        f.write(js)
                    log.info(f"Patched {name}: removed Bearer prefix")


def patch_rerank_https():
    """Fix HuggingFace rerank with HTTPS base_url.

    HuggingfaceRerank.post() hardcodes f"http://{url}/rerank", so passing
    base_url="https://host" produces "http://https://host/rerank" which
    tries to resolve "https" as a hostname.

    Fix: If URL contains "://", use it as-is with /rerank appended.
    """
    path = "/ragflow/rag/llm/rerank_model.py"
    if not os.path.exists(path):
        return
    with open(path) as f:
        code = f.read()
    old = 'f"http://{url}/rerank"'
    new = '(url.rstrip("/")+"/rerank" if "://" in url else f"http://{url}/rerank")'
    if old in code:
        code = code.replace(old, new, 1)
        with open(path, "w") as f:
            f.write(code)
        log.info("Patched rerank_model.py: HTTPS base_url support")


def patch_opensearch_conn():
    """Fix OSConnection for doc metadata service compatibility.

    1. Add missing create_doc_meta_idx() method (only implemented for ES/Infinity).
    2. Rename search() params from camelCase to snake_case to match new callers
       (doc_metadata_service.py, kb_app.py use snake_case kwargs).
       Old callers use positional args, so renaming is safe.
    """
    path = "/ragflow/rag/utils/opensearch_conn.py"
    if not os.path.exists(path):
        return
    with open(path) as f:
        code = f.read()

    changed = False

    # 1. Add create_doc_meta_idx method
    if "create_doc_meta_idx" not in code:
        method = """
    def create_doc_meta_idx(self, index_name: str):
        if self.index_exist(index_name, ''):
            return True
        try:
            import json as _json
            from opensearchpy.client import IndicesClient
            from common.file_utils import get_project_base_directory
            fp = os.path.join(get_project_base_directory(), 'conf', 'doc_meta_es_mapping.json')
            if not os.path.exists(fp):
                logger.error(f'doc_meta mapping not found: {fp}')
                return False
            with open(fp) as f:
                mapping = _json.load(f)
            return IndicesClient(self.os).create(index=index_name, body=mapping)
        except Exception:
            logger.exception('OSConnection.create_doc_meta_idx error %s' % index_name)
            return False

"""
        code = code.replace("    def delete_idx(", method + "    def delete_idx(", 1)
        changed = True
        log.info("Added OSConnection.create_doc_meta_idx")

    # 2. Fix search() parameter names: camelCase → snake_case
    renames = {
        "selectFields": "select_fields",
        "highlightFields": "highlight_fields",
        "matchExprs": "match_expressions",
        "orderBy": "order_by",
        "indexNames": "index_names",
        "knowledgebaseIds": "knowledgebase_ids",
        "aggFields": "agg_fields",
    }
    for old_name, new_name in renames.items():
        if old_name in code:
            code = code.replace(old_name, new_name)
            changed = True

    if changed:
        with open(path, "w") as f:
            f.write(code)
        log.info("Patched opensearch_conn.py: snake_case params + create_doc_meta_idx")


def main():
    log.info("Applying RAGFlow runtime patches...")
    patch_oidc_login()
    patch_rerank_https()
    patch_opensearch_conn()
    log.info("All patches applied")


if __name__ == "__main__":
    main()
