from pydantic import BaseModel, EmailStr, Field, ConfigDict


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1)


class ChangePasswordRequest(BaseModel):
    newPassword: str = Field(min_length=8)


class MasteryPayload(BaseModel):
    Phishing: float = 0.0
    Smishing: float = 0.0
    Vishing: float = 0.0
    Pretexting: float = 0.0
    Baiting: float = 0.0


class BuildingLevelsPayload(BaseModel):
    tower: int = 1
    glade: int = 1
    forge: int = 1


class StudentUserPayload(BaseModel):
    model_config = ConfigDict(serialize_by_alias=True)

    id: str = Field(serialization_alias="_id")
    name: str
    email: str
    role: str = "student"
    roleLabel: str = "Student"
    section: str | None = None
    status: str = "Needs Review"
    technical: bool = False
    pre: int = 0
    post: int = 0
    sessions: int = 0
    points: int = 0
    threatPoints: int = 0
    materials: int = 0
    highestUnlockedStage: int = 1
    buildingLevels: BuildingLevelsPayload = Field(default_factory=BuildingLevelsPayload)
    interventionStatus: str = "NORMAL"
    mastery: MasteryPayload
    preTestCompleted: bool = False


class LoginResponse(BaseModel):
    model_config = ConfigDict(serialize_by_alias=True)

    token: str
    mustChangePassword: bool = False
    user: StudentUserPayload


class ChangePasswordResponse(BaseModel):
    success: bool = True


class ErrorResponse(BaseModel):
    error: str
