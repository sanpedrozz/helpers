import os

EXCLUDE_DIRS = {'.git', '.idea', '__pycache__', '.venv', '.mypy_cache'}


def build_tree(start_path, prefix="", max_depth=4, current_depth=0):
    if current_depth >= max_depth:
        return []

    try:
        entries = [e for e in os.listdir(start_path) if e not in EXCLUDE_DIRS]
    except PermissionError:
        return []

    entries.sort()
    tree_lines = []
    entries_count = len(entries)

    for idx, entry in enumerate(entries):
        path = os.path.join(start_path, entry)
        connector = "└── " if idx == entries_count - 1 else "├── "
        line = f"{prefix}{connector}{entry}"
        tree_lines.append(line)

        if os.path.isdir(path):
            extension = "    " if idx == entries_count - 1 else "│   "
            subtree = build_tree(path, prefix + extension, max_depth, current_depth + 1)
            tree_lines.extend(subtree)

    return tree_lines


if __name__ == "__main__":
    result = build_tree("..", max_depth=6)
    output_file = "project_structure.txt"

    with open(output_file, "w", encoding="utf-8") as f:
        f.write("\n".join(result))

    print(f"Структура проекта сохранена в {output_file}")
