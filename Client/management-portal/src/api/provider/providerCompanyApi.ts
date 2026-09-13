import { apiClient } from '../../core/apiClient';

export interface CompanyDetails {
  _id: string;
  companyName: string;
  contactPerson?: { name?: string; phoneNumber?: string; email?: string };
  address?: { street?: string; city?: string; state?: string; country?: string; postalCode?: string };
  registrationNumber?: string;
  status?: 'Pending' | 'Rejected' | 'Accepted';
  isVerified?: boolean;
  profilePicture?: string;
  currency?: string;
  email?: string;
  username?: string;
}
export interface CompanyForm {
  companyName: string;
  contactPerson: { name: string; phoneNumber: string; email: string };
  address: { street: string; city: string; state: string; country: string; postalCode: string };
}
const endpoint = (id: string) => '/provider/company/' + encodeURIComponent(id);
export async function getCompany(id: string, signal?: AbortSignal) {
  return (await apiClient.get<CompanyDetails>(endpoint(id), { signal })).data;
}
export async function saveCompany(id: string, form: CompanyForm) {
  return (await apiClient.put<CompanyDetails>(endpoint(id), form)).data;
}
export async function uploadCompanyPhoto(id: string, file: File) {
  const form = new FormData();
  form.append('profilePicture', file);
  return (await apiClient.put<CompanyDetails>(endpoint(id) + '/photo', form, {
    timeout: 60_000,
    headers: { 'Content-Type': 'multipart/form-data' },
  })).data;
}
