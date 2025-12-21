-- Docker Container ExecDomains support for WezTerm
-- Automatically discovers and creates domains for running containers

local wezterm = require("wezterm")
local M = {}

-- Find docker binary path
local function get_docker_path()
    local paths = {
        "/opt/homebrew/bin/docker",
        "/usr/local/bin/docker",
        "/usr/bin/docker",
    }
    for _, path in ipairs(paths) do
        local f = io.open(path, "r")
        if f then
            f:close()
            return path
        end
    end
    return nil
end

local DOCKER_PATH = get_docker_path()

-- Get list of running docker containers with metadata
local function docker_list()
    local containers = {}
    if not DOCKER_PATH then
        return containers
    end

    local ok, success, stdout, stderr = pcall(wezterm.run_child_process, {
        DOCKER_PATH, "container", "ls", "--format",
        "{{.ID}}:{{.Names}}:{{.Label \"com.docker.compose.project\"}}:{{.Label \"devcontainer.local_folder\"}}"
    })

    if ok and success and stdout then
        for _, line in ipairs(wezterm.split_by_newlines(stdout)) do
            local id, name, compose_project, devcontainer_folder = line:match("([^:]*):([^:]*):([^:]*):([^:]*)")
            if id and name and id ~= "" then
                local container_type = "docker"
                local project_name = nil

                if name:match("devbox") then
                    container_type = "devbox"
                elseif devcontainer_folder and devcontainer_folder ~= "" then
                    container_type = "devcontainer"
                    project_name = devcontainer_folder:match("([^/]+)$")
                elseif compose_project and compose_project ~= "" then
                    container_type = "compose"
                    project_name = compose_project
                end

                table.insert(containers, {
                    id = id,
                    name = name,
                    type = container_type,
                    project = project_name,
                })
            end
        end
    end
    return containers
end

-- Create label function for container domain
local function make_docker_label_func(container)
    return function(name)
        local icon = "D"
        if container.type == "devbox" then
            icon = "B"
        elseif container.type == "devcontainer" then
            icon = "C"
        elseif container.type == "compose" then
            icon = "O"
        end

        local label = "[" .. icon .. "] " .. container.name
        if container.project then
            label = label .. " (" .. container.project .. ")"
        end

        return label
    end
end

-- Create fixup function for container domain
local function make_docker_fixup_func(container_id)
    return function(cmd)
        cmd.args = cmd.args or { "/bin/zsh", "-l" }
        local wrapped = { DOCKER_PATH, "exec", "-it", container_id }
        for _, arg in ipairs(cmd.args) do
            table.insert(wrapped, arg)
        end
        cmd.args = wrapped
        return cmd
    end
end

-- Compute exec domains from running containers
function M.compute_exec_domains()
    local exec_domains = {}
    if not DOCKER_PATH then
        return exec_domains
    end

    local ok, containers = pcall(docker_list)
    if not ok then
        return exec_domains
    end

    for _, container in ipairs(containers) do
        local domain_name = "docker:" .. container.name
        if container.type == "devbox" then
            domain_name = "devbox"
        elseif container.type == "devcontainer" then
            domain_name = "devcontainer:" .. (container.project or container.name)
        elseif container.type == "compose" then
            domain_name = "compose:" .. (container.project or container.name)
        end

        table.insert(
            exec_domains,
            wezterm.exec_domain(
                domain_name,
                make_docker_fixup_func(container.id),
                make_docker_label_func(container)
            )
        )
    end

    return exec_domains
end

-- Get launcher menu items for containers
function M.get_launcher_items()
    local items = {
        {
            label = "[H] Local Shell",
            args = { "/bin/zsh", "-l" },
        },
    }

    if DOCKER_PATH then
        local devbox_compose = os.getenv("HOME") .. "/.config/devbox/docker-compose.yml"
        local f = io.open(devbox_compose, "r")
        if f then
            f:close()
            table.insert(items, {
                label = "[B] Start Devbox",
                args = { DOCKER_PATH, "compose", "-f", devbox_compose, "up", "-d" },
            })
        end
    end

    return items
end

return M
