# predictor.py
# Инференс 1X2 + Over2.5 по уже обученным моделям.

import pandas as pd
from typing import Dict, Any

import joblib

from models.inference import predict_outcomes as infer_predict_outcomes, predict_totals as infer_predict_totals
from config import (
    OUTCOME_MODEL_PATH,
    TOTALS_MODEL_PATH,
)


class MatchPredictor(object):
    def __init__(self, outcome_pkl: str = OUTCOME_MODEL_PATH, totals_pkl: str = TOTALS_MODEL_PATH):
        self.outcome_bundle = joblib.load(outcome_pkl)
        self.totals_bundle = joblib.load(totals_pkl)

    # ========= 1X2 =========

    def _predict_outcome_batch(self, df: pd.DataFrame) -> np.ndarray:
        return infer_predict_outcomes(df, self.outcome_bundle)

    # ========= Totals =========

    def _predict_totals_batch(self, df: pd.DataFrame) -> np.ndarray:
        """
        Возвращает p(Over2.5) для батча.
        """
        return infer_predict_totals(df, self.totals_bundle)

    # ========= Публичный интерфейс =========

    def predict(self, df_features: pd.DataFrame) -> Dict[str, Any]:
        """
        df_features — датафрейм c полным набором фичей (как при обучении).
        Возвращает:
          {
            "p_outcome": np.ndarray [n, 3]  (away, draw, home),
            "p_over25": np.ndarray [n]
          }
        """
        P_out = self._predict_outcome_batch(df_features)
        p_ovr = self._predict_totals_batch(df_features)
        return {
            "p_outcome": P_out,
            "p_over25": p_ovr,
        }


if __name__ == "__main__":
    # Пример использования: df_features — свежий прематч-датасет
    # (без home_goals/away_goals, но с теми же фичами).
    predictor = MatchPredictor()
    # df_features = ...
    # res = predictor.predict(df_features)
    # print(res["p_outcome"][:5], res["p_over25"][:5])
    pass
