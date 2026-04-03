# predictor.py
# Инференс 1X2 + Over2.5 по уже обученным моделям.

import pandas as pd
import numpy as np
from typing import Dict, Any

import joblib

from models.inference import predict_outcomes as infer_predict_outcomes, predict_totals as infer_predict_totals
from models.totals_auxiliary import apply_totals_auxiliary
from models.epl_totals_head import apply_epl_totals_head
from models.epl_totals_model import apply_epl_totals_model
from config import (
    OUTCOME_MODEL_PATH,
    TOTALS_MODEL_PATH,
    TOTALS_AUX_MODEL_PATH,
    TOTALS_EPL_HEAD_MODEL_PATH,
    ENABLE_TOTALS_EPL_HEAD,
    TOTALS_EPL_MODEL_PATH,
    ENABLE_TOTALS_EPL_MODEL,
)


class MatchPredictor(object):
    def __init__(self, outcome_pkl: str = OUTCOME_MODEL_PATH, totals_pkl: str = TOTALS_MODEL_PATH):
        self.outcome_bundle = joblib.load(outcome_pkl)
        self.totals_bundle = joblib.load(totals_pkl)
        try:
            self.totals_aux_bundle = joblib.load(TOTALS_AUX_MODEL_PATH)
        except Exception:
            self.totals_aux_bundle = None
        self.totals_epl_head = None
        if ENABLE_TOTALS_EPL_HEAD:
            try:
                self.totals_epl_head = joblib.load(TOTALS_EPL_HEAD_MODEL_PATH)
            except Exception:
                self.totals_epl_head = None
        self.totals_epl_model = None
        if ENABLE_TOTALS_EPL_MODEL:
            try:
                self.totals_epl_model = joblib.load(TOTALS_EPL_MODEL_PATH)
            except Exception:
                self.totals_epl_model = None

    # ========= 1X2 =========

    def _predict_outcome_batch(self, df: pd.DataFrame) -> np.ndarray:
        return infer_predict_outcomes(df, self.outcome_bundle)

    # ========= Totals =========

    def _predict_totals_batch(self, df: pd.DataFrame) -> np.ndarray:
        """
        Возвращает p(Over2.5) для батча.
        """
        p = infer_predict_totals(df, self.totals_bundle)
        p = apply_totals_auxiliary(df, p, self.totals_aux_bundle)
        if self.totals_epl_model is not None:
            p = apply_epl_totals_model(df, p, self.totals_epl_model)
        if self.totals_epl_head is not None:
            p = apply_epl_totals_head(df, p, self.totals_epl_head)
        return p

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
