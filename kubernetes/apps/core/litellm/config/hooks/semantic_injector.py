# Inject LiteLLM's MCP server into eligible Responses and Chat Completions requests.
# Eligible virtual key aliases are listed in _SEMANTIC_MCP_KEY_ALIASES.
# LiteLLM's semantic filter then narrows the available tools based on the request.
# This hook does not grant MCP access; LiteLLM continues to enforce each virtual key's permissions.

from typing import Any

from litellm.caching.caching import DualCache
from litellm.integrations.custom_logger import CustomLogger
from litellm.proxy._types import UserAPIKeyAuth

_LITELLM_PROXY_MCP_TOOL = {
    "type": "mcp",
    "server_url": "litellm_proxy",
    "require_approval": "never",
}

# Add the alias of each virtual key that should receive semantic MCP filtering.
_SEMANTIC_MCP_KEY_ALIASES = {"zed"}


class SemanticMCPInjector(CustomLogger):
    async def async_pre_call_hook(
        self,
        user_api_key_dict: UserAPIKeyAuth,
        cache: DualCache,
        data: dict[str, Any],
        call_type: str,
    ) -> dict[str, Any] | None:
        if call_type not in {"aresponses", "acompletion", "completion"}:
            return None

        if (user_api_key_dict.key_alias or "").casefold() not in _SEMANTIC_MCP_KEY_ALIASES:
            return None

        if data.get("tool_choice") == "none":
            return None

        tools = data.get("tools")
        if tools is None:
            tools = []
            data["tools"] = tools
        elif not isinstance(tools, list):
            return None

        if any(
            isinstance(tool, dict)
            and tool.get("type") == "mcp"
            and tool.get("server_url") == "litellm_proxy"
            for tool in tools
        ):
            return None

        tools.append(_LITELLM_PROXY_MCP_TOOL.copy())
        return data

semantic_mcp_injector = SemanticMCPInjector()
