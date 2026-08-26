import axios from 'axios';

import { apiClient, apiErrorMessage } from '../../core/apiClient';
import {
  clearSession,
  isManagementRole,
  readSession,
  writeSession,
  type PortalSession,
  type PortalUser,
} from '../../core/session';

interface LoginResponse {
  message?: string;
  accessToken?: string;
  refreshToken?: string;
  user?: PortalUser;
}

export interface ProviderSignupInput {
  username: string;
  email: string;
  password: string;
  companyName: string;
  registrationNumber: string;
  contactName: string;
  contactPhone: string;
  contactEmail: string;
  street: string;
  city: string;
  state: string;
  country: string;
  postalCode: string;
  accountHolderName: string;
  accountNumber: string;
  bankName: string;
  iban: string;
  swiftCode: string;
  license: File;
  idCard: File;
  hasAcceptedTerms: boolean;
}

export async function loginManagementUser(
  identifier: string,
  password: string,
): Promise<PortalSession> {
  try {
    const response = await apiClient.post<LoginResponse>('/user/login', {
      identifier: identifier.trim(),
      password,
    });

    const { accessToken, refreshToken, user } = response.data;

    if (!accessToken || !refreshToken || !user?._id || !user.type) {
      throw new Error('The server returned incomplete session information.');
    }

    if (!isManagementRole(user.type)) {
      clearSession();
      throw new Error(
        'This portal is only available to administrators and providers.',
      );
    }

    const session: PortalSession = {
      accessToken,
      refreshToken,
      user,
    };

    writeSession(session);
    return session;
  } catch (error) {
    if (error instanceof Error && !axios.isAxiosError(error)) throw error;
    throw new Error(apiErrorMessage(error, 'Could not sign in.'));
  }
}

export async function registerProvider(
  input: ProviderSignupInput,
): Promise<string> {
  const form = new FormData();
  form.append('username', input.username.trim().toLowerCase());
  form.append('email', input.email.trim().toLowerCase());
  form.append('password', input.password);
  form.append('type', 'Provider');
  form.append('companyName', input.companyName.trim());
  form.append('registrationNumber', input.registrationNumber.trim());
  form.append(
    'contactPerson',
    JSON.stringify({
      name: input.contactName.trim(),
      phoneNumber: input.contactPhone.trim(),
      email: input.contactEmail.trim().toLowerCase(),
    }),
  );
  form.append(
    'address',
    JSON.stringify({
      street: input.street.trim(),
      city: input.city.trim(),
      state: input.state.trim(),
      country: input.country.trim(),
      postalCode: input.postalCode.trim(),
    }),
  );
  form.append(
    'bankDetails',
    JSON.stringify({
      accountHolderName: input.accountHolderName.trim(),
      accountNumber: input.accountNumber.trim(),
      bankName: input.bankName.trim(),
      IBAN: input.iban.trim(),
      swiftCode: input.swiftCode.trim(),
    }),
  );
  form.append('hasAcceptedTerms', String(input.hasAcceptedTerms));
  form.append('license', input.license);
  form.append('idCard', input.idCard);

  try {
    const response = await apiClient.post<{ message?: string }>(
      '/user/provider-signup',
      form,
      { headers: { 'Content-Type': 'multipart/form-data' } },
    );

    return response.data.message || 'Application submitted successfully.';
  } catch (error) {
    throw new Error(
      apiErrorMessage(error, 'Could not submit your application.'),
    );
  }
}

export async function logoutManagementUser(): Promise<void> {
  const refreshToken = readSession()?.refreshToken;

  try {
    if (refreshToken) {
      await apiClient.post('/user/logout', { refreshToken });
    }
  } catch {
    // Local logout must still work if the API is unavailable.
  } finally {
    clearSession();
  }
}

// Temporary compatibility for older portal components. New code should use
// logoutManagementUser.
export const logoutProvider = logoutManagementUser;
