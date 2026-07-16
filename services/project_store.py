import json
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass
class Project:
    user_id: int
    name: str
    requirements: str = ""
    generated_code: str = ""
    review: str = ""


class ProjectStore:
    def __init__(self, data_dir: str = "data") -> None:
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(parents=True, exist_ok=True)

    def _path(self, user_id: int) -> Path:
        return self.data_dir / f"{user_id}.json"

    def get(self, user_id: int) -> Project | None:
        path = self._path(user_id)
        if not path.exists():
            return None
        return Project(**json.loads(path.read_text(encoding="utf-8")))

    def save(self, project: Project) -> None:
        self._path(project.user_id).write_text(
            json.dumps(asdict(project), ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

    def create(self, user_id: int, name: str) -> Project:
        project = Project(user_id=user_id, name=name.strip())
        self.save(project)
        return project
