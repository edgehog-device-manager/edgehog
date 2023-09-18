/*
  This file is part of Edgehog.

  Copyright 2021-2023 SECO Mind Srl

  Licensed under the Apache License, Version 2.0 (the "License");
  you may not use this file except in compliance with the License.
  You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.

  SPDX-License-Identifier: Apache-2.0
*/

import { createContext, useContext, useMemo, useState } from "react";
import { IntlProvider } from "react-intl";

import en from "./langs-compiled/en.json";

const translationsByLanguage = { en };

type Language = keyof typeof translationsByLanguage;

const availableLanguages = Object.keys(translationsByLanguage) as Language[];

const defaultLanguage: Language = "en";

const getDefaultLanguage = () => {
  const browserLanguage = navigator.language.slice(0, 2);
  return browserLanguage in translationsByLanguage
    ? (browserLanguage as Language)
    : defaultLanguage;
};

type I18nContextValue = [Language, (language: Language) => void];

const I18nContext = createContext<I18nContextValue | null>(null);

interface I18nProviderProps {
  children?: React.ReactNode;
}

const I18nProvider = ({ children }: I18nProviderProps) => {
  const [language, setLanguage] = useState<Language>(getDefaultLanguage());

  const translations = useMemo(
    () =>
      translationsByLanguage[language] ||
      translationsByLanguage[defaultLanguage],
    [language],
  );

  const contextValue: I18nContextValue = useMemo(
    () => [language, setLanguage],
    [language],
  );

  return (
    <IntlProvider
      messages={translations}
      locale={language}
      defaultLocale={defaultLanguage}
    >
      <I18nContext.Provider value={contextValue}>
        {children}
      </I18nContext.Provider>
    </IntlProvider>
  );
};

const useLanguage = (): I18nContextValue => {
  const i18nContextValue = useContext(I18nContext);
  if (i18nContextValue == null) {
    throw new Error("I18nContext has not been Provided");
  }
  return i18nContextValue;
};

export type { Language };

export { availableLanguages, useLanguage };

export default I18nProvider;
