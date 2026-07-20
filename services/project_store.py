import json
import os
import sqlite3
from dataclasses import dataclass
from pathlib import Path


@dataclass
class Project:
    id: int
    user_id: int
    name: str
    requirements: str = ""
    generated_code: str = ""
    review: str = ""
    is_active: bool = True


class ProjectStore:
    """SQLite-backed project storage that survives bot restarts."""

    def __init__(self, db_path: str | None = None) -> None:
        configured_path = db_path or os.getenv("DB_PATH", "/app/data/ios_agent.db")
        self.db_path = Path(configured_path)
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        self._initialize()
        self._migrate_legacy_json()

    def _connect(self) -> sqlite3.Connection:
        connection = sqlite3.connect(self.db_path, timeout=30)
        connection.row_factory = sqlite3.Row
        connection.execute("PRAGMA journal_mode=WAL")
        connection.execute("PRAGMA foreign_keys=ON")
        return connection

    def _initialize(self) -> None:
        with self._connect() as connection:
            connection.executescript(
                """
                CREATE TABLE IF NOT EXISTS projects (
                    id INTEGER PRIMARY KEY AUTOINCREMENT,
                    user_id INTEGER NOT NULL,
                    name TEXT NOT NULL,
                    requirements TEXT NOT NULL DEFAULT '',
                    generated_code TEXT NOT NULL DEFAULT '',
                    review TEXT NOT NULL DEFAULT '',
                    is_active INTEGER NOT NULL DEFAULT 0,
                    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
                );

                CREATE INDEX IF NOT EXISTS idx_projects_user
                    ON projects(user_id);

                CREATE UNIQUE INDEX IF NOT EXISTS idx_one_active_project_per_user
                    ON projects(user_id)
                    WHERE is_active = 1;
                """
            )

    @staticmethod
    def _to_project(row: sqlite3.Row | None) -> Project | None:
        if row is None:
            return None
        return Project(
            id=int(row["id"]),
            user_id=int(row["user_id"]),
            name=str(row["name"]),
            requirements=str(row["requirements"] or ""),
            generated_code=str(row["generated_code"] or ""),
            review=str(row["review"] or ""),
            is_active=bool(row["is_active"]),
        )

    def get(self, user_id: int) -> Project | None:
        """Return the user's active project."""
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT id, user_id, name, requirements, generated_code, review, is_active
                FROM projects
                WHERE user_id = ? AND is_active = 1
                ORDER BY id DESC
                LIMIT 1
                """,
                (user_id,),
            ).fetchone()
        return self._to_project(row)

    def get_by_id(self, user_id: int, project_id: int) -> Project | None:
        with self._connect() as connection:
            row = connection.execute(
                """
                SELECT id, user_id, name, requirements, generated_code, review, is_active
                FROM projects
                WHERE user_id = ? AND id = ?
                """,
                (user_id, project_id),
            ).fetchone()
        return self._to_project(row)

    def list(self, user_id: int) -> list[Project]:
        with self._connect() as connection:
            rows = connection.execute(
                """
                SELECT id, user_id, name, requirements, generated_code, review, is_active
                FROM projects
                WHERE user_id = ?
                ORDER BY is_active DESC, updated_at DESC, id DESC
                """,
                (user_id,),
            ).fetchall()
        return [project for row in rows if (project := self._to_project(row)) is not None]

    def save(self, project: Project) -> None:
        with self._connect() as connection:
            cursor = connection.execute(
                """
                UPDATE projects
                SET name = ?, requirements = ?, generated_code = ?, review = ?,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = ? AND user_id = ?
                """,
                (
                    project.name.strip(),
                    project.requirements,
                    project.generated_code,
                    project.review,
                    project.id,
                    project.user_id,
                ),
            )
            if cursor.rowcount != 1:
                raise ValueError("Проект не найден в базе данных")

    def create(self, user_id: int, name: str) -> Project:
        clean_name = name.strip()
        if not clean_name:
            raise ValueError("Название проекта не может быть пустым")

        with self._connect() as connection:
            connection.execute(
                "UPDATE projects SET is_active = 0 WHERE user_id = ?",
                (user_id,),
            )
            cursor = connection.execute(
                """
                INSERT INTO projects(user_id, name, is_active)
                VALUES (?, ?, 1)
                """,
                (user_id, clean_name),
            )
            project_id = int(cursor.lastrowid)

        project = self.get_by_id(user_id, project_id)
        if project is None:
            raise RuntimeError("Не удалось создать проект")
        return project

    def activate(self, user_id: int, project_id: int) -> Project | None:
        with self._connect() as connection:
            exists = connection.execute(
                "SELECT 1 FROM projects WHERE user_id = ? AND id = ?",
                (user_id, project_id),
            ).fetchone()
            if exists is None:
                return None

            connection.execute(
                "UPDATE projects SET is_active = 0 WHERE user_id = ?",
                (user_id,),
            )
            connection.execute(
                """
                UPDATE projects
                SET is_active = 1, updated_at = CURRENT_TIMESTAMP
                WHERE user_id = ? AND id = ?
                """,
                (user_id, project_id),
            )

        return self.get(user_id)

    def delete(self, user_id: int, project_id: int) -> bool:
        with self._connect() as connection:
            row = connection.execute(
                "SELECT is_active FROM projects WHERE user_id = ? AND id = ?",
                (user_id, project_id),
            ).fetchone()
            if row is None:
                return False

            was_active = bool(row["is_active"])
            connection.execute(
                "DELETE FROM projects WHERE user_id = ? AND id = ?",
                (user_id, project_id),
            )

            if was_active:
                replacement = connection.execute(
                    """
                    SELECT id FROM projects
                    WHERE user_id = ?
                    ORDER BY updated_at DESC, id DESC
                    LIMIT 1
                    """,
                    (user_id,),
                ).fetchone()
                if replacement is not None:
                    connection.execute(
                        "UPDATE projects SET is_active = 1 WHERE id = ?",
                        (int(replacement["id"]),),
                    )
        return True

    def _migrate_legacy_json(self) -> None:
        """Import old data/<user_id>.json files once, without overwriting SQLite data."""
        legacy_dir = Path(os.getenv("LEGACY_DATA_DIR", "data"))
        if not legacy_dir.exists():
            return

        for path in legacy_dir.glob("*.json"):
            try:
                user_id = int(path.stem)
                payload = json.loads(path.read_text(encoding="utf-8"))
            except (ValueError, OSError, json.JSONDecodeError):
                continue

            with self._connect() as connection:
                already_exists = connection.execute(
                    "SELECT 1 FROM projects WHERE user_id = ? LIMIT 1",
                    (user_id,),
                ).fetchone()
                if already_exists is not None:
                    continue

                connection.execute(
                    """
                    INSERT INTO projects(
                        user_id, name, requirements, generated_code, review, is_active
                    ) VALUES (?, ?, ?, ?, ?, 1)
                    """,
                    (
                        user_id,
                        str(payload.get("name", "Без названия")),
                        str(payload.get("requirements", "")),
                        str(payload.get("generated_code", "")),
                        str(payload.get("review", "")),
                    ),
                )
